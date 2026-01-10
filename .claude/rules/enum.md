---
paths: app/models/**/*.rb
---

# Enum 定義ルール

[目的: Rails モデルにおける enum 定義の標準化とバリデーション強化]

## 必須ルール

### `validate: true` の付与

すべての enum 定義には `validate: true` を必ず付与すること。

```ruby
# 正しい例
enum :status, { active: 0, inactive: 1 }, validate: true

# 誤り（validate: true なし）
enum :status, { active: 0, inactive: 1 }
```

## 理由

`validate: true` を付与しない場合、無効な値が代入されると `ArgumentError` が発生する。
`validate: true` を付与することで、通常のバリデーションエラーとして扱われ、以下の利点がある：

1. **エラーハンドリングの一貫性**: ActiveRecord のバリデーションエラーとして統一的に処理できる
2. **ユーザー体験の向上**: 例外ではなくエラーメッセージとしてフィードバックできる
3. **API レスポンスの整合性**: 他のバリデーションエラーと同じ形式でレスポンスを返せる

## 実装パターン

### 基本形

```ruby
class Location < ApplicationRecord
  enum :status, { active: 0, inactive: 1 }, validate: true
end
```

### バリデーションエラーの確認

```ruby
location = Location.new(status: :invalid_status)
location.valid?  # => false
location.errors[:status]  # => ["は有効な値ではありません"]
```

## テストパターン

enum のバリデーションテストを必ず含めること。

```ruby
test "無効なステータスはバリデーションエラーになること" do
  location = Location.new(name: "テスト店舗", status: :invalid_status)
  assert_not location.valid?
  assert_includes location.errors[:status], "は有効な値ではありません"
end
```

---
_enum 定義時は常に `validate: true` を付与すること。例外は認めない。_
