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
  initial_stock = inventory.stock

  # Act
  inventory.decrement_stock!(3)
  inventory.reload

  # Assert
  assert_equal initial_stock - 3, inventory.stock
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

---
_フィクスチャの明示的宣言により、各テストの依存関係が明確になり、認知負荷が軽減される。_
