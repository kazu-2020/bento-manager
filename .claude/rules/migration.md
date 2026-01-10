---
paths: db/migrate/*.rb
---

# Migration Standards

[Purpose: マイグレーションファイルにおけるテーブル・カラムコメントの規約]

## Philosophy
- データベーススキーマは長期間維持される重要な資産
- コメントにより、時間が経ってもテーブル・カラムの意図が明確に残る
- Rails の `comment:` オプションを使用し、DBスキーマに直接コメントを保存

## Comment Guidelines

### 必須: テーブルコメント
テーブル作成時は必ず `comment:` オプションでテーブルの目的を記載する。

```ruby
create_table :locations, comment: "販売先マスタ" do |t|
  # ...
end
```

### 必須: ビジネスロジックを持つカラム
以下のカラムには必ずコメントを付与する:
- enum/status カラム: 状態値の意味を記載
- 業務上の意味を持つカラム: 用途や例を記載
- 制約のあるカラム: 制約の理由や例を記載

```ruby
t.string :name, null: false, comment: "販売先名称（例: 市役所、県庁）"
t.integer :status, null: false, default: 0, comment: "販売状態（0: active, 1: inactive）"
```

### 省略可: 自明なカラム
以下のカラムはコメント省略可:
- `id`: 主キーは自明
- `created_at`, `updated_at`: timestamps は自明
- `{table}_id`: 外部キーは命名で明確

## Pattern Examples

### Good: 適切なコメント
```ruby
create_table :locations, comment: "販売先マスタ" do |t|
  t.string :name, null: false, comment: "販売先名称（例: 市役所、県庁）"
  t.integer :status, null: false, default: 0, comment: "販売状態（0: active, 1: inactive）"
  t.timestamps  # コメント不要
end
```

### Bad: コメントなし
```ruby
create_table :locations do |t|
  t.string :name, null: false
  t.integer :status, null: false, default: 0
  t.timestamps
end
```

## Enum/Status Column Format
enum カラムのコメントは以下の形式で統一:
```
{日本語の意味}（0: value1, 1: value2, ...）
```

例:
```ruby
t.integer :status, comment: "販売状態（0: active, 1: inactive）"
t.integer :role, comment: "従業員種別（0: owner, 1: salesperson）"
```

## Migration Modification
既存テーブル/カラムへのコメント追加:
```ruby
change_table_comment :locations, "販売先マスタ"
change_column_comment :locations, :status, "販売状態（0: active, 1: inactive）"
```

---
_コメントはコードを見返す未来の自分・チームメンバーへの贈り物_
