# Testing Standards

テストの方針、構造、フィクスチャ管理のガイドライン。

## Philosophy

- **振る舞いをテスト**: 実装詳細ではなく、期待される動作をテスト
- **明示的な依存関係**: 各テストが必要とするフィクスチャを明示的に宣言
- **高速で信頼性のあるテスト**: 並列実行を活用し、フレーキーなテストを避ける

## Organization

```
test/
├── fixtures/           # フィクスチャファイル（YAML）
├── models/             # モデルテスト（ActiveSupport::TestCase）
├── integration/        # 統合テスト（ActionDispatch::IntegrationTest）
├── controllers/        # コントローラテスト
└── test_helper.rb      # 共通設定・ヘルパー
```

## Fixture Management

### 原則: 明示的なフィクスチャ宣言

`fixtures :all` は使用しない。各テストクラスで必要なフィクスチャを明示的に宣言する。

```ruby
# Good: 必要なフィクスチャのみ明示的に宣言
class CatalogTest < ActiveSupport::TestCase
  fixtures :catalogs

  test "..." do
    catalog = catalogs(:daily_bento_a)
  end
end

# Good: 複数フィクスチャの依存関係が明確
class DailyInventoryTest < ActiveSupport::TestCase
  fixtures :locations, :catalogs, :daily_inventories

  test "..." do
    inventory = daily_inventories(:city_hall_bento_a_today)
  end
end

# Good: フィクスチャ不使用（新規作成のみ）
class LocationTest < ActiveSupport::TestCase
  # fixtures 宣言なし

  test "name は一意" do
    Location.create!(name: "テスト市役所A")
    duplicate = Location.new(name: "テスト市役所A")
    assert_not duplicate.valid?
  end
end
```

### フィクスチャ依存関係マップ

| テストファイル | フィクスチャ |
|---------------|-------------|
| admin_test.rb | `:admins` |
| employee_test.rb | `:employees` |
| location_test.rb | なし |
| catalog_test.rb | `:catalogs` |
| catalog_price_test.rb | `:catalogs, :catalog_prices` |
| catalog_pricing_rule_test.rb | `:catalogs, :catalog_pricing_rules` |
| catalog_discontinuation_test.rb | `:catalogs, :catalog_discontinuations` |
| daily_inventory_test.rb | `:locations, :catalogs, :daily_inventories` |
| coupon_test.rb | `:coupons, :catalogs, :discounts` |
| discount_test.rb | `:coupons, :catalogs, :discounts` |
| sale_test.rb | `:locations, :employees, :sales` |
| sale_item_test.rb | `:locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items` |
| sales/recorder_test.rb | `:locations, :employees, :catalogs, :catalog_prices, :daily_inventories` |
| sales/refunder_test.rb | `:locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules, :daily_inventories, :coupons, :discounts, :sales, :sale_items` |
| refund_test.rb | `:locations, :employees, :catalogs, :catalog_prices, :daily_inventories, :sales, :sale_items` |
| catalogs/price_validator_test.rb | `:catalogs, :catalog_prices, :catalog_pricing_rules` |
| catalogs/pricing_rule_creator_test.rb | `:catalogs, :catalog_prices, :catalog_pricing_rules` |
| admin_authentication_test.rb | `:admins` |
| employee_authentication_test.rb | `:employees` |
| error_handling_test.rb | `:admins, :employees` |
| employees_controller_test.rb | `:admins, :employees` |

### フィクスチャ設計ガイドライン

- **最小限のレコード**: 各フィクスチャには必要最小限のレコードを定義
- **意図を表す名前**: `verified_admin`, `city_hall_bento_a_today` など
- **外部キー参照**: `<%= ActiveRecord::FixtureSet.identify(:reference_name) %>`
- **動的値**: ERB タグで日付やパスワードハッシュを生成

```yaml
# test/fixtures/catalog_prices.yml
daily_bento_a_regular:
  catalog: daily_bento_a
  kind: 0
  price: 550
  effective_from: <%= 1.month.ago.to_fs(:db) %>
  effective_until:
```

## Test Helpers

### 認証ヘルパー（統合テスト用）

```ruby
# test_helper.rb で定義済み
login_as(:verified_admin)              # シンボルで指定
login_as(admins(:verified_admin))      # オブジェクトで指定

login_as_employee(:verified_employee)
login_as_employee(employee, password: "custom")
```

## Test Structure

AAA パターン（Arrange-Act-Assert）に従う：

```ruby
test "在庫を減算できる" do
  # Arrange
  inventory = daily_inventories(:city_hall_bento_a_today)

  # Act & Assert
  assert_difference -> { inventory.reload.stock }, -3 do
    inventory.decrement_stock!(3)
  end
end
```

## State Change Assertions

DB のレコード数や属性値の増減を検証する場合、一時変数を使わず Rails テストヘルパーを利用する。

### assert_difference（レコード数・数値の増減）

```ruby
# Good: レコード数の増加
assert_difference "Sale.count" do
  create_sale
end

# Good: 複数レコードの同時検証
assert_no_difference [ "Sale.count", "SaleItem.count" ] do
  invalid_operation
end

# Good: 数値の増減（ラムダ使用）
assert_difference -> { inventory.reload.stock }, -3 do
  inventory.decrement_stock!(3)
end

# Bad: 一時変数を使用
initial_count = Sale.count
create_sale
assert_equal initial_count + 1, Sale.count
```

参考: [assert_difference API](https://api.rubyonrails.org/v8.1/classes/ActiveSupport/Testing/Assertions.html#method-i-assert_difference)

### assert_changes（属性値の変化）

```ruby
# Good: from/to で具体値を指定
assert_changes -> { inventory.reload.stock }, from: 10, to: 8 do
  inventory.decrement_stock!(2)
end

# Good: 変化しないことを検証（ロールバック確認）
assert_no_changes -> { inventory.reload.stock } do
  assert_raises ActiveRecord::RecordNotFound do
    recorder.record(invalid_params)
  end
end

# Bad: 一時変数を使用
initial_stock = inventory.stock
inventory.decrement_stock!(2)
inventory.reload
assert_equal initial_stock - 2, inventory.stock
```

参考: [assert_changes API](https://api.rubyonrails.org/v8.1/classes/ActiveSupport/Testing/Assertions.html#method-i-assert_changes)

### 使い分け

| ヘルパー | 用途 | 例 |
|---------|------|-----|
| `assert_difference` | レコード数や数値の増減 | `Sale.count`, `inventory.stock` |
| `assert_no_difference` | 変化しないことを検証 | ロールバック、バリデーション失敗 |
| `assert_changes` | 任意の属性値の変化（from/to 指定） | `user.status`, `order.state` |
| `assert_no_changes` | 属性値が変化しないこと | トランザクションロールバック |

### ネストによる複合検証

```ruby
test "トランザクションでロールバックされる" do
  inventory = daily_inventories(:city_hall_bento_a_today)

  assert_no_difference [ "Sale.count", "SaleItem.count" ] do
    assert_no_changes -> { inventory.reload.stock } do
      assert_raises ActiveRecord::RecordNotFound do
        @recorder.record(@sale_params, invalid_items)
      end
    end
  end
end
```

## Test Types

| 種類 | 継承クラス | 用途 |
|-----|-----------|------|
| Model | `ActiveSupport::TestCase` | バリデーション、スコープ、ビジネスロジック |
| Integration | `ActionDispatch::IntegrationTest` | 認証フロー、エラーハンドリング |
| Controller | `ActionDispatch::IntegrationTest` | CRUD 操作、アクセス制御 |

## Running Tests

```bash
# 全テスト実行（並列）
bundle exec rails test

# 特定ファイル
bundle exec rails test test/models/catalog_test.rb

# 特定テスト（行番号指定）
bundle exec rails test test/models/catalog_test.rb:96
```

## Component Testing

ViewComponent のテストパターン。

### 構成

```
test/
└── components/
    ├── example_component_test.rb   # コンポーネントテスト
    └── previews/
        └── example_component_preview.rb  # Lookbook プレビュー
```

### テストパターン

```ruby
# test/components/example_component_test.rb
require "test_helper"

class ExampleComponentTest < ViewComponent::TestCase
  def test_renders_title
    render_inline(ExampleComponent.new(title: "Hello"))

    assert_text "Hello"
    assert_selector "h2"
  end

  def test_renders_with_block_content
    render_inline(ExampleComponent.new(title: "Test")) do
      "Block content"
    end

    assert_text "Block content"
  end
end
```

### プレビュー（Lookbook 用）

```ruby
# test/components/previews/example_component_preview.rb
class ExampleComponentPreview < ViewComponent::Preview
  # @param title text
  def default(title: "サンプルタイトル")
    render(ExampleComponent.new(title: title))
  end

  def with_long_title
    render(ExampleComponent.new(title: "これは非常に長いタイトルの例です"))
  end
end
```

開発環境で `/lookbook` にアクセスしてプレビューを確認できる。

---
_フィクスチャの明示的宣言により、各テストの依存関係が明確になり、認知負荷が軽減される。_

_updated_at: 2026-01-11_
