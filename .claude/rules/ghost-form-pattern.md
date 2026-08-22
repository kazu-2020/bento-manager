---
paths:
  - "app/controllers/pos/locations/**/form_states_controller.rb"
  - "app/models/**/*_form.rb"
  - "app/views/components/pos/**/*ghost_form/*.erb"
  - "app/views/pos/locations/**/form_states/*.erb"
---

# Ghost Form パターン

[目的: 価格計算やバリデーションを JS に二重実装せず、サーバーサイドでリアルタイムに UI を更新する]

POS 画面（販売、返品、日次在庫、在庫訂正、追加発注）で採用している共通パターン。
ユーザーが操作するメインフォームとは別に、非表示の「幽霊フォーム」を置き、状態変更をサーバーへ送って UI を再描画する。

## 必須ルール

### 1. リアルタイム更新にメインフォームを流用しない

メインフォームの送信先は確定処理（販売確定・在庫登録など）である。数量変更のたびに送信すると確定処理が走ってしまう。
UI 更新専用の Ghost Form を別エンドポイントへ送る。

```
メインフォーム → POST /pos/locations/:id/sales            → 販売確定
Ghost Form    → POST /pos/locations/:id/sales/form_state  → UI 更新のみ
```

ルーティングは単数リソースで定義し、標準アクションのみを使う（[controller-actions.md](controller-actions.md) 準拠）。

```ruby
resource :form_state, only: [ :create ]
```

### 2. パラメータは `ghost_` プレフィックスで名前空間を分ける

`ghost_form_controller.js` がメインフォームの `FormData` を読み取り、`ghost_` を付けた同名の hidden field へ転写する。
Ghost Form 側の input 名は必ずメインフォームと対応させること（対応する input が無い値は黙って捨てられる）。

```
cart[<catalog_id>][quantity]        → ghost_cart[<catalog_id>][quantity]
refund[corrected][<id>][quantity]   → ghost_refund[corrected][<id>][quantity]
```

**対象レコードの id は、両方の送信先とも URL で持つ。** 差額精算は `sale_id` で対象の販売を
指す唯一の画面で（他の 4 画面は `location` だけで足り、path に含まれる）、これをメインフォームに
hidden で持たせると誰も読まない `ghost_sale_id` が要ることになる。Ghost Form の送信先 URL は
既に `sale_id` を持っているためである。2 つの URL は `Refunds::RefundForm` に隣り合わせで置く
（`form_with_options` / `form_state_options`）。片方だけ落とすと、確定と再描画のどちらかが
`sale_id` を失って 404 になる（`set_sale` の `find(nil)` が `RecordNotFound`）。
別の販売が拾われる経路は無い。

**ただし `ghost_` の付かない入力が正当な画面もある。** 当日在庫・在庫訂正・追加発注の
検索欄は、メインフォーム側が `search_field_tag :search_query`、Ghost Form 側が
**プレフィックス無しの** `hidden_field_tag :search_query` で、`search_form_controller.js` が
転写を介さず直接書き込む。ユーザーが打ち込む欄なので URL には載せられない。
在庫訂正は当日在庫と同じ `pos/daily_inventories/new_form` を描くので、検索欄も同じ 1 つである。
この 3 画面に `assert_ghost_inputs_correspond` を当てるときは、この 1 件をどう扱うかを
先に決めること（未着手。素直に当てると `missing: search_query` で落ちる）。

対応関係はメインフォーム側（`product_card` / `coupon_card` / `submit_button`）と Ghost Form 側の
**別々の ERB リテラル**で決まるため、片方をリネームしても例外は出ない。実 ERB をレンダリングして
機械的に突き合わせる
[`GhostFormCorrespondenceHelper`](test/support/ghost_form_correspondence_helper.rb) があるので、
Ghost Form を持つ画面には `assert_ghost_inputs_correspond` を呼ぶテストを 1 本置くこと。
現在の適用は販売画面（[new_form_component_test.rb](test/components/pos/sales/new_form_component_test.rb)）と
差額精算画面（[new_page_component_test.rb](test/components/pos/refunds/new_page_component_test.rb)）で、
当日在庫・在庫訂正・追加発注は未適用。

配線は Stimulus コントローラー2つの組み合わせで行う。

```erb
<div data-controller="ghost-form pos-cart"
     data-action="pos-cart:cartChanged->ghost-form#submit">
  <form data-ghost-form-target="originalForm">...</form>
  <form data-ghost-form-target="ghostForm" data-turbo-stream="true">...</form>
</div>
```

数量変更の検知側（`pos_cart_controller` 等）は 300ms デバウンスしてから `cartChanged` を発火する。デバウンスなしで送るとリクエストが過剰になる。

### 3. フォームオブジェクトは確定用とリアルタイム用で共有する

`ActiveModel::Model` を include した PORO を `app/models/{domain}/*_form.rb` に置き、`FormStatesController` と確定用コントローラーの**両方**から同じクラスを使う。渡すパラメータの名前空間が違うだけで、価格計算もバリデーションも同一ロジックを通す。

```ruby
# FormStatesController（Ghost Form 受信）
@form = build_form(submitted_params(:ghost_cart, form: ::Sales::CartForm))

# SalesController（メインフォーム受信）
@form = build_form(submitted_params(:cart, form: ::Sales::CartForm))
```

`build_form` / `set_*` は両コントローラーで共有するため concern に切り出す
（[cart_form_buildable.rb](app/controllers/concerns/cart_form_buildable.rb) が最小の形。
[refund_form_buildable.rb](app/controllers/concerns/refund_form_buildable.rb) はそこに
販売の状態を見るガードが加わる）。現在の適用は販売・差額精算・追加発注の 3 画面で、
当日在庫・在庫訂正は未適用（`build_form` が両コントローラーに重複したまま、
`search_query` を渡すかどうかが片方だけ食い違っている）。

### 4. パラメータは SubmittedParamsFilterable 経由で取り出す

送信キーが catalog_id や discount_id で実行時にしか決まらないため `permit` のホワイトリストを静的に書けない。
`SubmittedParamsFilterable` を include し、フォームクラスを渡して取り出す。`to_unsafe_h` を直接呼んではいけない。

```ruby
# app/models/sales/cart_form.rb — どの位置に何が来るかはフォームが宣言する
SUBMITTED_PARAMS_SHAPE = {
  scalar_keys: %w[customer_type],
  collection_keys: %w[coupon]
}.freeze

# app/controllers/pos/locations/sales_controller.rb
@form = build_form(submitted_params(:cart, form: ::Sales::CartForm))
```

宣言と合わない値は黙って破棄される。フォームが新しく `submitted["foo"]` を読むようになったら
`SUBMITTED_PARAMS_SHAPE` の更新が必須で、忘れると値が捨てられる。
検証できる構造と、そう決めた理由は [params_filter.rb](app/models/ghost_forms/params_filter.rb) に書いてある。

### 5. 「未送信」「送信されたが読めない」「送信あり」を状態として扱う

`submitted_params` は素のハッシュではなく [`GhostForms::Submission`](app/models/ghost_forms/submission.rb) を返す。
フィルタ後の中身が空かどうかだけで分岐してはいけない。不正なパラメータだけの送信は
フィルタで空に畳まれるため、「まだ何も送られていない」と見分けがつかなくなり、
初期値の再構築や「全て 0」の確定に化ける。返品なら修正後の販売が作られないまま元の販売が
取り消されて全額返金になり、在庫訂正なら拒否すべき要求が `bulk_recreate` で既存在庫を
破壊的に作り直す。

| 状態 | 判定 | 意味 |
| --- | --- | --- |
| 未送信 | `submitted.absent?` | 初回描画。元の販売や既存在庫から初期値を作る |
| 送信されたが読めない | `submitted.unreadable?(必須キー)` | 壊れた送信。差し戻す |
| 送信あり | 上記以外 | `submitted.values` を読む |

**何が必須かはフォームが決める**。既定は最上位全体で、一部のキーだけが必須なフォームは
`required_submitted_keys` を上書きする。返品は `corrected` さえ届けば `coupon` は空でよいので、
引数なしの `unreadable?` は成り立たない（`unreadable?` に既定値を置いていないのはこのため）。

差し戻しはフォームが担う。[`GhostForms::SubmissionReadable`](app/models/ghost_forms/submission_readable.rb)
を include し、`@submitted` に `Submission` を代入すれば `:unreadable_submission` が付く。
判定を呼ぶのは concern だけで、フォームやコントローラーが `unreadable?` を直接叩くことはない。
同じフォームは確定用と Ghost Form 用の 2 つのコントローラーから組み立てられるため（ルール 3）、
コントローラーに置くと片方が素通しになる。

```ruby
class RefundForm
  include ::GhostForms::SubmissionReadable

  def initialize(sale:, submitted: ::GhostForms::Submission.absent)
    @submitted = submitted
    @corrected_quantities = submitted.absent? ? default_quantities : read(submitted["corrected"])
  end

  private

  # 送信されたなら必ず中身があるはずの最上位キー。上書きしなければ最上位全体を見る
  def required_submitted_keys
    %w[corrected]
  end
end
```

`Submission` が見るのは密化前の、届いたままのハッシュである（ルール 7）。密にしたあとの
数量ハッシュは母集合の分だけ必ず埋まるので、そちらで空判定をしてはいけない。

**`absent` を作れるのはフォームの既定引数（＝`new` アクション）だけ**で、`submitted_params`
経由で作られた submission は絶対に `absent` にならない。名前空間ごとキーが届かない POST も
「未送信」ではなく壊れた送信として扱う。ここを畳むと在庫訂正が既存在庫からの再構築に化けて
`bulk_recreate` が走る。

`absent?` を見てよいのは初期値の作り分けだけで、拒否の判断に使ってはいけない。
その作り分けもフォームが持つ。items の組み立てをコントローラーに置くと、
送信ありなのに初期値から組んだ items という、あり得ないはずの状態が作れてしまう。
文言は `ja.activemodel.errors.messages.unreadable_submission` に 1 つだけ置いてあり、
新しいフォームが include しても翻訳の追加は要らない。

### 6. Turbo Stream で Ghost Form 自身も差し替える

再描画対象に Ghost Form を含めないと、hidden field が古い状態のまま残り、次の送信で以前の値を送ってしまう。

```erb
<%# form_states/create.turbo_stream.erb %>
<%= turbo_stream.replace "price-breakdown" do %>
  <%= component "pos/sales/price_breakdown", form: @form %>
<% end %>

<%# Ghost Form 自体も必ず更新する %>
<%= turbo_stream.replace "ghost-form" do %>
  <%= component "pos/sales/ghost_form", form: @form %>
<% end %>
```

### 7. 数量ハッシュは母集合に対して密にする

無効化された input はブラウザが送信しない。届かないキーは 0 を意味するが、疎なハッシュを
そのまま公開すると、その規則を読み手が各自 `|| 0` で書き直すことになり、1 人でも書き忘れると
黙って古い値が復活する。フォームオブジェクトの構築時に、母集合のキーを 1 つ残らず埋めること。

**母集合は画面が入力を描画する範囲そのもの**にする。描画されないキーを母集合に入れると、
送信されようがないものを「0 に減った」と読んでしまう（例: 販売後に有効期限が切れたクーポンは
`available_discounts` から外れるので、母集合も `available_discounts` に揃える）。

```ruby
# app/models/ghost_forms/quantities.rb
def self.dense(ids, source)
  ids.index_with { |id| source[id] || 0 }
end
```

母集合の決め方だけが各フォームの責務で、埋める処理そのものは共有する。

密にすると現在値と初期値が同じキー集合になるので、変更判定はキーの和集合を走査せず
`current != original` で足りる。

なお「送信されたが中身が空」は壊れた送信であって「全て 0」ではない。密にしたハッシュは
母集合の分だけ必ず埋まるため空かどうかでは見分けられない。埋める前の、届いたままの
ハッシュで判定すること（ルール 5 の `GhostForms::Submission` がこれを担う）。

## 理由

1. **ロジックの一元化**: 価格計算・在庫判定がサーバーに集約され、JS 側での二重実装が要らない
2. **テスタビリティ**: フォームオブジェクトは PORO なので単体テストが容易
3. **Progressive Enhancement**: JavaScript が無効でも、メインフォームによる確定処理は動作する

---
_リアルタイム更新は Ghost Form 経由で行い、メインフォームは確定処理専用に保つこと。_
