# Issue #109: 追加発注画面で全てのお弁当を選択可能にする

## Context

追加発注画面では、当日の在庫（`DailyInventory`）に登録された弁当のみが選択肢として表示される。しかし、当日の仕込みの都合で在庫未登録の弁当を追加発注する場面がある（例: 朝はトルコライスを持参したが、追加発注ではトルコライスカレーが必要になる等）。

変更内容:
1. 選択肢の起点を「当日の在庫」から「全弁当カタログ」に変更する
2. 全弁当が一覧に並ぶと選択が大変になるため、「在庫登録済み / 未登録」タブ + 検索バーを追加する
3. 検索は日次在庫登録ページと同じ Ghost Form + Turbo Stream パターンで実装する

## 変更ファイル一覧

| # | ファイル | 変更種別 |
|---|---|---|
| 1 | `config/routes.rb` | 変更: form_state ルート追加 |
| 2 | `app/controllers/pos/locations/additional_orders_controller.rb` | 変更: データ取得ロジック |
| 3 | `app/controllers/pos/locations/additional_orders/form_states_controller.rb` | **新規**: Ghost Form 用 |
| 4 | `app/views/pos/locations/additional_orders/form_states/create.turbo_stream.erb` | **新規**: Turbo Stream |
| 5 | `app/models/additional_orders/order_form.rb` | 変更: シグネチャ + 検索 + タブ |
| 6 | `app/models/additional_orders/order_item.rb` | 変更: `in_inventory` 属性追加 |
| 7 | `app/views/components/pos/additional_orders/order_form/component.rb` | 変更: タブ・検索メソッド |
| 8 | `app/views/components/pos/additional_orders/order_form/component.html.erb` | 変更: Ghost Form + 検索 + タブ UI |
| 9 | `app/views/components/pos/additional_orders/order_form/component.yml` | 変更: i18n 追加 |
| 10 | `app/views/components/pos/additional_orders/order_form_ghost_form/component.rb` | **新規** |
| 11 | `app/views/components/pos/additional_orders/order_form_ghost_form/component.html.erb` | **新規** |
| 12 | `app/views/components/pos/additional_orders/order_item_card/component.rb` | 変更: `hidden:` パラメータ追加 |
| 13 | `app/views/components/pos/additional_orders/order_item_card/component.html.erb` | 変更: hidden ラッパー追加 |
| 14 | テストファイル（コントローラー・モデル） | 変更・追加 |

## 変更詳細

### 1. ルーティング (`config/routes.rb`)

既存パターン（`daily_inventories`, `sales`）と同様に `form_state` ルートを追加:

```ruby
# 既存
resources :additional_orders, only: [ :index, :new, :create ], module: :locations
# 追加
namespace :additional_orders, module: "locations/additional_orders" do
  resource :form_state, only: [ :create ]
end
```

### 2. コントローラー (`additional_orders_controller.rb`)

**before_action の整理:**
- `set_inventories` を `only: :index` に限定（index ページの `InventorySummary` コンポーネントが `@inventories` を参照するため）
- `redirect_unless_inventories` は `@location.has_today_inventory?` を使う（Location 既存メソッド: `location.rb:15`）

**`build_form` の変更:**
- 全弁当カタログ + 在庫マップを取得し、OrderForm に渡す

```ruby
before_action :set_location
before_action :set_inventories, only: :index
before_action :redirect_unless_inventories
before_action :set_additional_orders, only: :index

def redirect_unless_inventories
  return if @location.has_today_inventory?
  redirect_to new_pos_location_daily_inventory_path(@location)
end

def build_form(submitted = {})
  catalogs = Catalog.bento.available.order(:kana)
  stock_map = @location.today_inventories
                       .where(catalog_id: catalogs.select(:id))
                       .to_h { |inv| [inv.catalog_id, inv.available_stock] }

  ::AdditionalOrders::OrderForm.new(
    location: @location,
    catalogs: catalogs,
    stock_map: stock_map,
    submitted: submitted
  )
end
```

### 3. FormStatesController (**新規**: `additional_orders/form_states_controller.rb`)

日次在庫登録の `FormStatesController` (`daily_inventories/form_states_controller.rb`) と同じパターン。

```ruby
module Pos
  module Locations
    module AdditionalOrders
      class FormStatesController < ApplicationController
        before_action :set_location

        def create
          @form = build_form(submitted_params(:ghost_order))
          respond_to { |format| format.turbo_stream }
        end

        private

        def set_location
          @location = Location.active.find(params[:location_id])
        end

        def build_form(submitted = {})
          catalogs = Catalog.bento.available.order(:kana)
          stock_map = @location.today_inventories
                               .where(catalog_id: catalogs.select(:id))
                               .to_h { |inv| [inv.catalog_id, inv.available_stock] }

          ::AdditionalOrders::OrderForm.new(
            location: @location,
            catalogs: catalogs,
            stock_map: stock_map,
            search_query: params[:search_query],
            submitted: submitted
          )
        end

        def submitted_params(key)
          return {} unless params[key]
          params[key].to_unsafe_h
        end
      end
    end
  end
end
```

**キーの変換**: `ghost_form_controller.js` が `order[123][quantity]` → `ghost_order[123][quantity]` に自動変換するため、パラメータキーは `ghost_order` で受ける。

### 4. Turbo Stream テンプレート (**新規**: `form_states/create.turbo_stream.erb`)

日次在庫登録の `create.turbo_stream.erb` と同じパターン:

```erb
<%# 各商品カードを更新 %>
<% @form.items.each do |item| %>
  <%= turbo_stream.replace "order-item-#{item.catalog_id}" do %>
    <%= component "pos/additional_orders/order_item_card",
                  item: item,
                  hidden: !@form.visible?(item) %>
  <% end %>
<% end %>

<%# Ghost Form を更新 %>
<%= turbo_stream.replace "ghost-form" do %>
  <%= component "pos/additional_orders/order_form_ghost_form",
                form_state_options: @form.form_state_options,
                items: @form.items,
                search_query: @form.search_query %>
<% end %>
```

### 5. OrderForm (`order_form.rb`)

**シグネチャ変更**: `inventories:` → `catalogs:` + `stock_map:` + `search_query:`

**追加メソッド**: `visible?`, `inventory_items`, `non_inventory_items`, `form_state_options`

```ruby
attr_reader :items, :location, :created_count, :search_query

def initialize(location:, catalogs:, stock_map: {}, search_query: nil, submitted: {})
  @location = location
  @catalogs = catalogs
  @stock_map = stock_map
  @search_query = search_query&.strip.presence
  @items = build_items(submitted)
  @created_count = 0
end

def visible?(item)
  return true if search_query.blank?
  item.catalog_name.include?(search_query)
end

def inventory_items
  items.select(&:in_inventory?)
end

def non_inventory_items
  items.reject(&:in_inventory?)
end

def form_state_options
  { url: pos_location_additional_orders_form_state_path(location), method: :post }
end

private

def build_items(submitted)
  @catalogs.map do |catalog|
    saved = submitted[catalog.id.to_s] || {}
    AdditionalOrders::OrderItem.new(
      catalog_id: catalog.id,
      catalog_name: catalog.name,
      available_stock: @stock_map[catalog.id] || 0,
      in_inventory: @stock_map.key?(catalog.id),
      quantity: saved[:quantity].to_i
    )
  end
end
```

### 6. OrderItem (`order_item.rb`)

`in_inventory` 属性を追加:

```ruby
attribute :in_inventory, :boolean, default: false
```

### 7-9. OrderForm コンポーネント

**設計方針:**
- 最外ラッパーに `data-controller="ghost-form"` をアタッチ
- 検索バーに `data-controller="search-form"` をアタッチ（既存 `search_form_controller.js` を再利用）
- タブに既存 `tabs_controller.js` を再利用
- タブは `inventory_items` / `non_inventory_items` 両方にアイテムがある場合のみ表示

**component.rb に追加するメソッド:**
```ruby
delegate :inventory_items, :non_inventory_items, :form_state_options, :search_query, to: :form

def show_tabs?
  inventory_items.any? && non_inventory_items.any?
end
```

**component.html.erb のイメージ:**

注意: 検索バーは `form_with` の**外側**に配置する（日次在庫登録と同じ構造。内側に置くと注文送信時に `search_query` が一緒に送信される）。

```erb
<div data-controller="ghost-form"
     data-action="search-form:searchSubmit->ghost-form#submit">

  <%# 検索バー（form_with の外側） %>
  <div data-controller="search-form">
    <label class="input input-bordered flex items-center gap-2 mb-4">
      <%= helpers.icon "magnifying_glass", extra_class: "opacity-50" %>
      <%= search_field_tag :search_query, search_query,
            placeholder: t(".search_placeholder"),
            class: "grow text-base",
            autocomplete: "off", inputmode: "search",
            data: { search_form_target: "input", action: "input->search-form#search" } %>
    </label>
  </div>

  <%# オリジナルフォーム %>
  <%= form_with **form_with_options, id: "additional-order-form",
        data: { ghost_form_target: "originalForm" } do |f| %>

    <% if show_tabs? %>
      <div data-controller="tabs">
        <div role="tablist" class="tabs tabs-lift">
          <button type="button" role="tab" class="tab min-h-12 flex-1 text-base font-medium tab-active"
                  data-tabs-target="tab" data-action="tabs#select">
            <%= t(".inventory_tab") %>
          </button>
          <button type="button" role="tab" class="tab min-h-12 flex-1 text-base font-medium"
                  data-tabs-target="tab" data-action="tabs#select">
            <%= t(".non_inventory_tab") %>
          </button>
        </div>

        <div data-tabs-target="panel" class="space-y-1 py-2">
          <% inventory_items.each do |item| %>
            <%= render_item_card(item) %>
          <% end %>
        </div>
        <div data-tabs-target="panel" hidden class="space-y-1 py-2">
          <% non_inventory_items.each do |item| %>
            <%= render_item_card(item) %>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="space-y-1">
        <% items.each do |item| %>
          <%= render_item_card(item) %>
        <% end %>
      </div>
    <% end %>
  <% end %>

  <%# Ghost Form %>
  <%= render_ghost_form %>
</div>
```

**component.yml:**
```yaml
ja:
  section_title: 追加発注
  search_placeholder: 商品名で検索...
  inventory_tab: 在庫登録済み
  non_inventory_tab: 未登録
```

### 10-11. Ghost Form コンポーネント (**新規**: `order_form_ghost_form/`)

日次在庫登録の `new_form_ghost_form` と同じパターン。

**component.rb:**
```ruby
module Pos
  module AdditionalOrders
    module OrderFormGhostForm
      class Component < Application::Component
        def initialize(form_state_options:, items:, search_query: nil)
          @form_state_options = form_state_options
          @items = items
          @search_query = search_query
        end
        attr_reader :form_state_options, :items, :search_query
      end
    end
  end
end
```

**component.html.erb:**
```erb
<%= form_with **form_state_options,
              id: "ghost-form",
              data: { turbo_stream: true, ghost_form_target: "ghostForm" } do |f| %>
  <%= hidden_field_tag :search_query, search_query %>
  <% items.each do |item| %>
    <%= hidden_field_tag "ghost_order[#{item.catalog_id}][quantity]", item.quantity %>
  <% end %>
<% end %>
```

**キー変換のしくみ**: `ghost_form_controller.js` がオリジナルフォームの `order[123][quantity]` を読み取り、Ghost Form の `ghost_order[123][quantity]` に書き込む。

### 12-13. OrderItemCard コンポーネント変更

`hidden:` パラメータを追加し、検索フィルタ時の表示/非表示を制御:

**component.rb に追加:**
```ruby
def initialize(item:, hidden: false)
  @item = item
  @hidden = hidden
end

def hidden?
  @hidden
end

def wrapper_classes
  class_names("hidden": hidden?)
end
```

**component.html.erb**: 外側に `dom_id` 付きのラッパーを追加:
```erb
<%= fields_for item_field_name, item do |f| %>
  <div id="<%= dom_id %>" class="<%= wrapper_classes %>">
    <div class="<%= card_classes %>">
      <%# 既存のカード内容 %>
    </div>
  </div>
<% end %>
```

### 14. テスト

**コントローラーテスト** (`additional_orders_controller_test.rb`):
- 「在庫未登録の弁当もフォームに表示される」テスト追加
- 既存の「サイドメニューが表示されない」テストはそのまま有効
- 在庫未登録の弁当テストデータはテスト内で `Catalog.create!` で作成（fixture 追加は不要） <!-- dig-plan で追記 -->

**FormStatesController テスト** (新規):
- 検索クエリで商品が絞り込まれることを確認（Turbo Stream レスポンス）

**OrderForm テスト** (`order_form_test.rb`):
- `setup` を新シグネチャに更新
- `visible?`, `inventory_items`, `non_inventory_items` のテスト追加
- `form_state_options` のテスト追加

## 変更不要なファイル

- **AdditionalOrder** (`additional_order.rb`): `create_with_inventory!` の `find_or_create_by!` で在庫自動作成。`stock`/`reserved_stock` のDBデフォルト値 `0` で問題なし
- **DailyInventory** (`daily_inventory.rb`): 変更不要
- **NewPage コンポーネント**: 変更不要
- **Stimulus コントローラー**: `search_form_controller.js`, `ghost_form_controller.js`, `tabs_controller.js` すべて既存をそのまま再利用

## 注意点・制約 <!-- dig-plan で追記 -->

- **index ページの `@inventories` 依存**: `InventorySummary` コンポーネントが使うため `set_inventories` を `only: :index` に限定する（完全削除はNG）
- **`redirect_unless_inventories` の判定変更**: 「弁当在庫があるか」→「何かしらの在庫があるか」に変わるが業務上問題なし（ユーザー確認済み）
- **検索とタブの連携**: 検索はタブ切り替え時もクリアしない。両タブで同じ検索条件が適用される（ユーザー確認済み）
- **非表示アイテムのフォーム送信**: 検索で非表示にしたアイテムの数量はリセットされず送信される（ユーザー確認済み）
- **Ghost Form の検索トリガーのみ**: 日次在庫登録ではチェックボックス変更時にも Ghost Form を submit するが、追加発注では検索入力のみがトリガー（数量変更では submit しない）
- **検索バーの配置**: `form_with` の外側に配置する（日次在庫登録と同じ構造。内側だと注文送信時に `search_query` が送信される） <!-- dig-plan で追記 -->
- **検索結果なしの表示**: 不要。空のリストがそのまま表示される（ユーザー確認済み） <!-- dig-plan で追記 -->
- **テストデータ**: 在庫未登録弁当のテストデータは fixture ではなくテスト内で `Catalog.create!` で作成する（ユーザー確認済み） <!-- dig-plan で追記 -->

## 検証

1. `bin/rails test` で全テスト通過を確認
2. `bin/rubocop -a` で Lint 通過を確認
3. ブラウザで追加発注画面を開き:
   - 「在庫登録済み」タブに当日在庫の弁当が表示されること
   - 「未登録」タブに在庫未登録の弁当が「残 0個」で表示されること
   - 検索バーで商品名の絞り込みが動作すること（Turbo Stream で更新）
   - タブ切り替え時に検索条件が維持されること
   - 在庫未登録の弁当で追加発注後、DailyInventory が自動作成されること
4. index ページの在庫サマリーが正常に表示されることを確認

---

## CodeRabbit レビュー対応（テスト強化）

### Context

PR #111 に対する CodeRabbit レビューで 5件の Nitpick 指摘を受けた。精査の結果、以下の3件を対応推奨と判断。いずれもテストの検証強度を上げる変更であり、プロダクションコードの変更はなし。

### 変更対象ファイル

| # | ファイル | 変更内容 |
|---|---------|---------|
| 1 | `test/controllers/pos/locations/additional_orders/form_states_controller_test.rb` | 検索テストに非一致商品の hidden 検証追加 |
| 2 | `test/models/additional_orders/order_form_test.rb` | URL 完全一致検証に変更 |
| 3 | `test/models/additional_orders/order_form_test.rb` | 在庫未登録弁当の自動作成テスト追加 |

### 変更詳細

#### 1. 検索テストに非一致商品の hidden 検証追加

`form_states_controller_test.rb` L67-76

**現状**: 一致商品（弁当A）の存在のみ確認
**問題**: フィルタ処理が壊れても通る
**対応**: `@bento_b` が `class="hidden"` 付きで返されることを検証

```ruby
test "検索クエリで商品を絞り込める" do
  login_as_employee(@employee)
  bento_b = catalogs(:daily_bento_b)

  post pos_location_additional_orders_form_state_path(@location),
       params: { search_query: "弁当A" },
       headers: { "Accept" => "text/vnd.turbo-stream.html" }

  assert_response :success
  # 一致商品は表示される（hidden なし）
  assert_match "order-item-#{@bento_a.id}", response.body
  # 非一致商品は hidden クラス付き
  assert_match(/id="order-item-#{bento_b.id}"[^>]*class="hidden"/, response.body)
end
```

注意: Turbo Stream レスポンスは HTML フラグメントなので `assert_select` が使えない。`assert_match` + 正規表現で `id` と `class="hidden"` の対応を検証する。

#### 2. form_state_options の URL 完全一致検証

`order_form_test.rb` L113-119

**現状**: `assert_includes options[:url], @location.id.to_s`（部分一致）
**問題**: 誤った URL でも location_id を含めば通る
**対応**: route helper で期待 URL を生成し `assert_equal` で完全一致

```ruby
test "form_state_options が正しいURLとメソッドを返す" do
  form = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map)
  options = form.form_state_options

  assert_equal :post, options[:method]
  assert_equal "/pos/locations/#{@location.id}/additional_orders/form_state", options[:url]
end
```

`OrderForm` が既に `Rails.application.routes.url_helpers` を include しているため、テスト内で route helper を使うよりも、期待するパス文字列をリテラルで書く方が「仕様書」として分かりやすい。

#### 3. 在庫未登録弁当の DailyInventory 自動作成テスト追加

`order_form_test.rb` に新規テスト追加

**現状**: 既存テストは bento_a, bento_b とも在庫登録済み（fixture に存在）
**問題**: PR の中核機能「在庫未登録弁当の追加発注 → DailyInventory 自動作成」の退行テストがない
**対応**: テスト内で在庫未登録の弁当を作成し、注文後に DailyInventory が自動作成されることを検証

```ruby
test "在庫未登録の弁当を追加発注すると在庫レコードが自動作成される" do
  unlisted = Catalog.create!(name: "トルコライスカレー", kana: "トルコライスカレー", category: :bento)
  catalogs = Catalog.bento.available.order(:kana)
  stock_map = @location.today_inventories
                       .where(catalog_id: catalogs.select(:id))
                       .to_h { |inv| [inv.catalog_id, inv.available_stock] }

  assert_not stock_map.key?(unlisted.id)

  submitted = { unlisted.id.to_s => { quantity: "3" } }
  form = OrderForm.new(location: @location, catalogs: catalogs, stock_map: stock_map, submitted: submitted)

  assert_difference ["AdditionalOrder.count", "DailyInventory.count"], 1 do
    assert form.save(employee: @employee)
  end

  created_inventory = @location.today_inventories.find_by!(catalog_id: unlisted.id)
  assert_equal 3, created_inventory.stock
end
```

### 検証

1. `bin/rails test test/controllers/pos/locations/additional_orders/form_states_controller_test.rb test/models/additional_orders/order_form_test.rb` で対象テスト通過
2. `bin/rails test` で全テスト通過
3. `bin/rubocop -a` で Lint 通過
