# Ghost Form パターン - リアルタイム UI 更新のための設計パターン

本ドキュメントは、POS レジ機能（販売画面）で採用している **Ghost Form パターン** について解説する。

---

## 1. Ghost Form パターンとは

Ghost Form パターンは、ユーザーが操作するメインフォームとは別に、**非表示の「幽霊フォーム」** を配置し、
メインフォームの状態変更をサーバーへ送信して **リアルタイムに UI を更新する** 設計パターンである。

### 解決する課題

POS レジ画面では、ユーザーが商品の数量やクーポンを変更するたびに以下を即座に反映する必要がある。

- 合計金額・小計の再計算
- セット価格の適用判定（弁当 + サラダ）
- クーポンの適用可否
- 送信ボタンの有効/無効切り替え
- 在庫状況の表示更新

これらの計算ロジックはサーバー側（`Sales::PriceCalculator`）に集約されているため、
クライアント側で計算ロジックを二重管理することなく、サーバーサイドレンダリングでリアルタイム更新を実現している。

---

## 2. 構成要素

| 要素 | ファイル | 役割 |
|------|---------|------|
| メインフォーム | `pos/sales/new_form/component.html.erb` | ユーザーが操作する販売フォーム |
| Ghost Form | `pos/sales/ghost_form/component.html.erb` | 非表示の影フォーム |
| Ghost Form Controller | `ghost_form_controller.js` | メイン→Ghost のデータ転写・送信 |
| POS Cart Controller | `pos_cart_controller.js` | 数量変更の検知・デバウンス |
| FormStatesController | `pos/locations/sales/form_states_controller.rb` | Ghost Form を受け取りレスポンス返却 |
| CartForm | `app/models/sales/cart_form.rb` | フォームオブジェクト（状態管理・価格計算） |
| Turbo Stream テンプレート | `form_states/create.turbo_stream.erb` | DOM 差分更新のレスポンス |

---

## 3. なぜ 2 つのフォームが必要なのか

### メインフォームだけでは不十分な理由

メインフォームの送信先は `POST /pos/locations/:id/sales`（販売確定）である。
数量変更のたびにメインフォームを送信すると、**販売処理が実行されてしまう**。

### Ghost Form の役割

Ghost Form は別のエンドポイント `POST /pos/locations/:id/sales/form_state` に送信する。
このエンドポイントは **販売処理を行わず、現在のカート状態に基づいて UI を再描画する** だけである。

```
メインフォーム  → POST /pos/locations/:id/sales           → 販売確定
Ghost Form     → POST /pos/locations/:id/sales/form_state → UI 更新のみ
```

---

## 4. データフロー

### 4.1 リアルタイム更新（Ghost Form 経由）

1. ユーザーがメインフォームで数量を変更
2. `pos_cart_controller` が変更を検知し、300ms デバウンス後に `cartChanged` イベントを発火
3. `ghost_form_controller` がメインフォームの全データを読み取り、Ghost Form の hidden field に転写
4. Ghost Form が `form_state` エンドポイントへ Turbo Stream リクエストとして送信
5. `FormStatesController` が `CartForm` を再構築し、価格計算を実行
6. Turbo Stream レスポンスで各コンポーネントの DOM を差し替え

### 4.2 販売確定（メインフォーム）

1. ユーザーが送信ボタンを押下
2. メインフォームが `SalesController#create` へ送信
3. `CartForm` でバリデーション後、`Sales::Recorder` が販売レコードを作成

---

## 5. 実装の詳細

### 5.1 Stimulus Controller の連携

```html
<!-- new_form/component.html.erb -->
<div data-controller="ghost-form pos-cart"
     data-action="pos-cart:cartChanged->ghost-form#submit">

  <!-- メインフォーム（ユーザー操作用） -->
  <form data-ghost-form-target="originalForm" ...>
    <!-- 商品カード、クーポン、送信ボタン -->
  </form>

  <!-- Ghost Form（非表示） -->
  <form id="ghost-form"
        data-ghost-form-target="ghostForm"
        data-turbo-stream="true" ...>
    <!-- hidden fields -->
  </form>
</div>
```

2 つの Stimulus Controller が連携して動作する。

- **`pos_cart_controller`**: 数量変更を検知し、デバウンスして `cartChanged` カスタムイベントを発火
- **`ghost_form_controller`**: `cartChanged` を受けてメインフォームのデータを Ghost Form に転写し、送信

### 5.2 パラメータの名前空間

メインフォームと Ghost Form はパラメータ名の prefix で区別される。

```
# メインフォーム
cart[<catalog_id>][quantity]
cart[coupon][<discount_id>][quantity]
cart[customer_type]

# Ghost Form（ghost_ prefix）
ghost_cart[<catalog_id>][quantity]
ghost_cart[coupon][<discount_id>][quantity]
ghost_cart[customer_type]
```

`ghost_form_controller.js` がメインフォームの `cart[...]` を読み取り、
Ghost Form の `ghost_cart[...]` に値をコピーする。

### 5.3 Turbo Stream による DOM 更新

```erb
<%# form_states/create.turbo_stream.erb %>

<%# 商品カード更新 %>
<% @form.items.each do |item| %>
  <%= turbo_stream.replace "cart-item-#{item.catalog_id}" do %>
    <%= component "pos/sales/product_card", item: item %>
  <% end %>
<% end %>

<%# 価格内訳更新 %>
<%= turbo_stream.replace "price-breakdown" do %>
  <%= component "pos/sales/price_breakdown", form: @form %>
<% end %>

<%# Ghost Form 自体も更新 %>
<%= turbo_stream.replace "ghost-form" do %>
  <%= component "pos/sales/ghost_form", form: @form %>
<% end %>
```

Turbo Stream レスポンスにより、以下の DOM 要素が差し替えられる。

| ターゲット ID | 更新内容 |
|--------------|---------|
| `cart-item-{catalog_id}` | 商品カードの状態（在庫、数量） |
| `price-breakdown` | 小計・割引額・合計金額 |
| `coupon-card-{discount_id}` | クーポンの適用可否 |
| `sale-submit-button` | 送信ボタンの有効/無効 |
| `ghost-form` | Ghost Form 自身（最新の hidden values） |

---

## 6. CartForm - フォームオブジェクトの設計

`Sales::CartForm` は ActiveRecord モデルに紐づかない **PORO（Plain Old Ruby Object）** である。
`ActiveModel::Model` を include することで、フォームとしてのインターフェースを備える。

### 責務

- メインフォーム / Ghost Form **両方** のデータを同一のロジックで処理
- `CartItem` オブジェクトの構築と管理
- `Sales::PriceCalculator` への委譲による価格計算
- バリデーション（商品が 1 つ以上、顧客タイプの選択）

### 二重利用

```ruby
# FormStatesController（Ghost Form 受信）
@form = CartForm.new(location:, inventories:, discounts:, submitted: params[:ghost_cart])

# SalesController（メインフォーム受信）
@form = CartForm.new(location:, inventories:, discounts:, submitted: params[:cart])
```

同じ `CartForm` クラスが、リアルタイム更新時と販売確定時の両方で使われる。
渡されるパラメータの名前空間（`ghost_cart` or `cart`）が異なるだけで、処理は同一である。

---

## 7. パターンのメリットと注意点

### メリット

| メリット | 説明 |
|---------|------|
| ロジックの一元化 | 価格計算・バリデーションがサーバー側に集約され、JS での二重実装が不要 |
| SSR の利点維持 | Turbo Stream によるサーバーサイドレンダリングで、SPA 的な体験を実現 |
| テスタビリティ | CartForm / PriceCalculator は PORO なので単体テストが容易 |
| Progressive Enhancement | JavaScript が無効でもメインフォームによる販売確定は動作する |

### 注意点

| 注意点 | 対策 |
|--------|------|
| リクエスト頻度 | デバウンス（300ms）で過度なリクエストを抑制 |
| ネットワーク遅延 | Turbo Stream の非同期処理で UX への影響を最小化 |
| Ghost Form の同期 | Turbo Stream レスポンスで Ghost Form 自体も更新し、常に最新状態を維持 |

---

## 8. 図

本パターンのデータフローについては、同ディレクトリの draw.io 図を参照。

- `20260226_ghost_form_pattern.drawio.svg` - Ghost Form パターンのシーケンス図
