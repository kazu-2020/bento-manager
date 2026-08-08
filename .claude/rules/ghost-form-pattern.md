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
refund[items][<id>][quantity]       → ghost_refund[items][<id>][quantity]
```

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
@form = build_form(submitted_params(:ghost_cart))

# SalesController（メインフォーム受信）
@form = build_form(submitted_params(:cart))
```

`build_form` / `submitted_params` / `set_*` は両コントローラーで共有するため concern に切り出す（例: [refund_form_buildable.rb](app/controllers/concerns/refund_form_buildable.rb)）。

```ruby
def submitted_params(key)
  return {} unless params[key]

  params[key].to_unsafe_h
end
```

### 4. Turbo Stream で Ghost Form 自身も差し替える

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

## 理由

1. **ロジックの一元化**: 価格計算・在庫判定がサーバーに集約され、JS 側での二重実装が要らない
2. **テスタビリティ**: フォームオブジェクトは PORO なので単体テストが容易
3. **Progressive Enhancement**: JavaScript が無効でも、メインフォームによる確定処理は動作する

---
_リアルタイム更新は Ghost Form 経由で行い、メインフォームは確定処理専用に保つこと。_
