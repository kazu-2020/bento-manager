---
paths:
  - "test/**/*.rb"
---

# テスト記述ルール

[目的: 仕様書として読めるテストを古典学派スタイルで記述する]

## 必須ルール

### 1. 古典学派スタイル（Classical School）

モックを使わず、fixture + 実DB操作で振る舞いを検証する。

```ruby
# 正しい例: fixture と実DBを使用
test "販売先の当日在庫には今日の日付のデータだけが含まれる" do
  city_hall = locations(:city_hall)
  today_inventories = city_hall.today_inventories

  assert_equal 3, today_inventories.size
end

# 避けるべき例: モックで依存を差し替え
test "当日在庫を取得する" do
  location = Location.new
  mock_inventories = [mock(), mock()]
  location.stubs(:daily_inventories).returns(mock_inventories)
  # ...
end
```

テストダブルは外部API等、本当に必要な場合のみ使用する。

### 2. テスト名の付け方

**業務フロー**（モデル/サービスの振る舞い）: 非エンジニアが読める日本語にする。

```ruby
# 正しい例: ビジネスルールを表現
test "販売先一覧は稼働中を先に表示し、同じ状態では名前の昇順で並ぶ" do
test "当日の在庫がない販売先は在庫なしと判定される" do

# 避けるべき例: 実装詳細が露出
test "display_order は active を先に、同じ status 内では name 昇順" do
```

**内部ユーティリティ**（型変換、パーサー、ファクトリー等）: 技術的な記述でよい。

```ruby
# OK: 非エンジニアに説明する意味がない技術テスト
test "casts hash with symbol keys to InventoryItem" do
test "returns nil for unsupported types" do
```

判定基準: 「非エンジニアに説明する意味があるか」で使い分ける。

### 3. shoulda-matchers の使い分け

**validations / associations**: shoulda-matchers で宣言的にテスト

```ruby
test "validations" do
  @subject = Location.new(name: "テスト拠点")

  must validate_presence_of(:name)
  must validate_uniqueness_of(:name).case_insensitive
  must define_enum_for(:status).with_values(active: 0, inactive: 1).validating
end

test "associations" do
  @subject = Location.new

  must have_many(:daily_inventories).dependent(:restrict_with_error)
end
```

**スコープ / インスタンスメソッド**: 古典学派スタイルで振る舞いをテスト

```ruby
test "販売先の当日在庫には今日の日付のデータだけが含まれる" do
  city_hall = locations(:city_hall)
  # 実際のメソッド呼び出しと結果の検証
  assert_equal 3, city_hall.today_inventories.size
end
```

### 4. テストの粒度

1テスト = 1業務フロー。同じ業務概念を扱うテストは分割せず1つにまとめる。

```ruby
# 正しい例: 「提供終了」という業務フローを1テストで検証
test "提供終了した商品は販売可能な一覧から除外される" do
  available = Catalog.create!(name: "販売中弁当", kana: "ハンバイチュウベントウ", category: :bento)
  discontinued = Catalog.create!(name: "終了弁当", kana: "シュウリョウベントウ", category: :bento)
  CatalogDiscontinuation.create!(catalog: discontinued, discontinued_at: Time.current, reason: "終了")

  assert discontinued.discontinued?
  assert_not available.discontinued?
  assert_includes Catalog.available, available
  assert_not_includes Catalog.available, discontinued
end

# 避けるべき例: 同じ概念を3テストに分割
test "提供終了記録がある商品は提供終了と判定される" do ...end
test "提供終了記録がない商品は提供中と判定される" do ...end
test "販売可能な商品には提供終了していないものだけが含まれる" do ...end
```

**テスト不要なもの（フレームワーク保証）:**

- enum のスコープ（`Catalog.bento`）、変更メソッド（`catalog.bento!`）→ `define_enum_for` でカバー
- スコープのチェーン（`Catalog.available.bento`）→ Rails の ActiveRecord が保証

### 5. フィクスチャは明示的に宣言する

`fixtures :all` は使用しない。各テストクラスで必要なフィクスチャだけを宣言し、依存関係を可視化する。

```ruby
# 正しい例: 必要なフィクスチャのみ宣言
class DailyInventoryTest < ActiveSupport::TestCase
  fixtures :locations, :catalogs, :daily_inventories

  test "..." do
    inventory = daily_inventories(:city_hall_bento_a_today)
  end
end

# 正しい例: 新規作成のみのテストは宣言不要
class LocationTest < ActiveSupport::TestCase
  test "name は一意" do
    Location.create!(name: "テスト市役所A")
  end
end
```

フィクスチャは必要最小限のレコードにとどめ、`verified_employee` や `city_hall_bento_a_today` のように意図が読める名前を付ける。

宣言したフィクスチャはプロセス内の全テストから見えるため、**集計や件数を検証するテストは共有フィクスチャを対象にしない**。
`locations(:city_hall)` のような共有レコードを集計対象にすると、他テストクラスが宣言したフィクスチャが混入する。
テスト内で専用のレコードを作り、自分が作ったデータだけを集計対象にする。

```ruby
# 正しい例: 集計対象を自分で作る
setup do
  @location = Location.create!(name: "集計テスト販売先", status: :active)
end

# 避けるべき例: 共有フィクスチャを集計し、掃除で辻褄を合わせる
setup do
  Sale.delete_all  # 他クラスのフィクスチャ流入を消して回ることになる
end
```

### 6. 状態変化は Rails のアサーションで検証する

DB のレコード数や属性値の増減は、一時変数を使わず `assert_difference` / `assert_changes` で表現する。

```ruby
# 正しい例: レコード数の増減
assert_difference "Sale.count" do
  create_sale
end

# 正しい例: 数値の増減（ラムダ使用）
assert_difference -> { inventory.reload.stock }, -3 do
  inventory.decrement_stock!(3)
end

# 正しい例: from/to で具体値を指定
assert_changes -> { inventory.reload.stock }, from: 10, to: 8 do
  inventory.decrement_stock!(2)
end

# 正しい例: ネストでトランザクションのロールバックを検証
assert_no_difference [ "Sale.count", "SaleItem.count" ] do
  assert_no_changes -> { inventory.reload.stock } do
    assert_raises ActiveRecord::RecordNotFound do
      @recorder.record(@sale_params, invalid_items)
    end
  end
end

# 避けるべき例: 一時変数を使用
initial_count = Sale.count
create_sale
assert_equal initial_count + 1, Sale.count
```

| ヘルパー | 用途 |
|---------|------|
| `assert_difference` / `assert_no_difference` | レコード数や数値の増減 |
| `assert_changes` / `assert_no_changes` | 任意の属性値の変化（from/to 指定） |

### 7. ViewComponent は render_inline で検証する

コンポーネントテストは `ViewComponent::TestCase` を継承し、`test/components/{namespace}/{name}_component_test.rb` に配置する（コンポーネント本体のディレクトリ構造とは対応しない）。プレビューは `test/components/previews/` に置き、開発環境の `/lookbook` で確認する。

```ruby
# test/components/locations/list_component_test.rb
class Locations::ListComponentTest < ViewComponent::TestCase
  def test_renders_grid_with_locations
    result = render_inline(Locations::List::Component.new(locations: [ @location1 ]))

    assert_predicate result.css(".grid"), :present?
    assert_includes result.to_html, @location1.name
  end
end
```

共通のテストヘルパーは `test/support/` に置く（`test_helper.rb` で自動読み込み済み）。

`t()` はレンダリング前に呼ぶと `TranslateCalledBeforeRenderError` になる。`render_inline` を先に実行してからメソッド経由でデータを参照する。

## 理由

1. **仕様書としての価値**: テスト名がそのままドキュメントになる
2. **保守性**: 実装が変わってもビジネスルールが同じならテスト名は変わらない
3. **信頼性**: 実DBを使うことで統合的な動作を保証

---
_テストは「何をするか」ではなく「どう振る舞うか」を記述すること。_
