# CodeRabbit レビュー対応: テスト強化

## Context

PR #111 に対する CodeRabbit レビューで 5件の Nitpick 指摘を受けた。精査の結果、以下の3件を対応推奨と判断。いずれもテストの検証強度を上げる変更であり、プロダクションコードの変更はなし。

## 変更対象ファイル

| # | ファイル | 変更内容 |
|---|---------|---------|
| 1 | `test/controllers/pos/locations/additional_orders/form_states_controller_test.rb` | 検索テストに非一致商品の hidden 検証追加 |
| 2 | `test/models/additional_orders/order_form_test.rb` | URL 完全一致検証に変更 |
| 3 | `test/models/additional_orders/order_form_test.rb` | 在庫未登録弁当の自動作成テスト追加 |

## 変更詳細

### 1. 検索テストに非一致商品の hidden 検証追加

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

注意: Turbo Stream レスポンスは HTML フラグメントなので `assert_select` が使えない。`assert_match` + 正規表現で検証。

### 2. form_state_options の URL 完全一致検証

`order_form_test.rb` L113-119

**現状**: `assert_includes options[:url], @location.id.to_s`（部分一致）
**問題**: 誤った URL でも location_id を含めば通る
**対応**: 期待するパス文字列リテラルで `assert_equal` 完全一致

```ruby
test "form_state_options が正しいURLとメソッドを返す" do
  form = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map)
  options = form.form_state_options

  assert_equal :post, options[:method]
  assert_equal "/pos/locations/#{@location.id}/additional_orders/form_state", options[:url]
end
```

### 3. 在庫未登録弁当の DailyInventory 自動作成テスト追加

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

## 検証

1. `bin/rails test test/controllers/pos/locations/additional_orders/form_states_controller_test.rb test/models/additional_orders/order_form_test.rb`
2. `bin/rails test` で全テスト通過
3. `bin/rubocop -a` で Lint 通過
