---
paths:
  - "app/views/**/*.turbo_stream.erb"
  - "app/views/components/modal/**/*"
  - "app/helpers/modal_stream_helper.rb"
---

# モーダルの構造

[目的: 5 画面のモーダルを同じ形に保ち、閉じる操作とフレーム差し替えの事故を再発させない]

## 必須ルール

### 1. モーダルは `modal_stream_show` からしか開かない

`<dialog class="modal">` / `.modal-box` / 閉じるフォーム / backdrop は `Modal::Component` が出す。
テンプレートに直接書いてはいけない。書くと backdrop の抜けや閉じるフォームの配置ずれが画面ごとに生まれる。

```erb
<%= modal_stream_show do %>
  <%= render "shared/modal_title", title: price_form.modal_title %>
  <%= render price_form %>
<% end %>
```

### 2. 見出しは殻に含めず、呼び出し側が `shared/_modal_title` で置く

`modal_stream_show` は `title:` を受け取らない。

`catalogs/new` はタイトルがカテゴリで変わり、カテゴリ選択が turbo-frame をナビゲートするため、
見出しが**フレームの中**に入る。殻が `title:` を受け取る形にすると、この画面だけ渡さないことになり、
「渡さない＝自分でフレームの中に置く」という、シグネチャから読めない契約が生まれる。
見出しを常に呼び出し側が置けば、フレームの中でも外でも同じ 1 行で書ける。

### 3. 閉じるフォームは turbo-frame の外に置く

`Modal::Component` が `.modal-box` の直下・本体より前に出す。フレームの中に入れると
フレーム差し替えで消え、キャンセルボタンの `form=` が宙に浮いてモーダルが閉じなくなる。

キャンセルボタンは `form="<%= modal_close_form_id %>"` で所有者を閉じるフォームへ移すこと。
そうしないとテキスト欄の Enter が「保存」ではなくキャンセルに化ける。
仕組みは `ModalStreamHelper::MODAL_CLOSE_FORM_ID` のコメントに書いてある。

### 4. 幅は指定しない

`.modal-box` は daisyUI 既定の `max-width: 32rem`（Tailwind の `max-w-lg` と同値）で揃える。
画面ごとに `max-w-*` を足さない。`Modal::Component` は幅パラメータを持たない。

### 5. turbo-frame は差し替えが実在する画面にだけ置く

**フレームの範囲はコントローラが何を replace するかで決まる。**

| 差し替える単位 | frame の位置 | 例 |
| --- | --- | --- |
| Component 1 つ | その Component のテンプレートの中 | `catalog_prices/edit` |
| 見出し + フォームなど複数 | 呼び出し側テンプレートの `modal_stream_show` ブロックの中 | `catalogs/new` |

Component を `turbo_stream.replace(FRAME_ID, Component.new)` で直接差し替える画面
（`CatalogPricesController#update`）では、Component 自身が frame タグを出さなければならない。
`replace` は対象要素を丸ごと置き換えるので、出さないと 1 回目の差し替えで frame が消え、
2 回目のバリデーションエラーが届かなくなる。

**差し替える経路が無いなら frame を置かない。** 使われない frame は
「ここはフレーム差し替えされる」という嘘の契約になり、ルール 3 の制約を、実際には起きない
事故に対して守らせることになる。バリデーションエラーで `render :new` して
`modal_stream_show` を返す画面（`discounts` / `locations`）は、モーダル全体を再描画しているので
frame は要らない。

## テスト

- 殻の構造（dialog / modal-box / 閉じるフォームの位置 / backdrop / 幅なし）は
  [modal_component_test.rb](test/components/modal_component_test.rb) が 1 本で守る
- 各画面のフォーム側の責務（送信ボタンが 1 個、キャンセルが `form=` を持つ）は
  コントローラテストの `assert_modal_cancel_uses_close_form` が守る。モーダルを 1 枚足したら
  この assert も 1 本足すこと
- frame を置いた画面は `assert_close_form_survives_frame_replacement` で、閉じるフォームが
  フレームの外にあることを守る。frame の無い画面では使わない

---
_モーダルは `modal_stream_show` からしか開かない。見出しは呼び出し側、殻は Modal::Component。_
