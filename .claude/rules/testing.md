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

## 理由

1. **仕様書としての価値**: テスト名がそのままドキュメントになる
2. **保守性**: 実装が変わってもビジネスルールが同じならテスト名は変わらない
3. **信頼性**: 実DBを使うことで統合的な動作を保証

---
_テストは「何をするか」ではなく「どう振る舞うか」を記述すること。_
