---
paths:
  - "app/controllers/**/*.rb"
  - "app/models/**/*.rb"
---

# Eager Loading ルール

ActiveRecord のアソシエーション読み込み戦略に関するルール。

---

## 基本方針

`includes` は状況によりクエリが変わりコントロールしづらいため、**基本的に使用しない**。
代わりに `eager_load` と `preload` を明示的に使い分ける。

---

## 使い分けルール

| アソシエーション | 使用メソッド | 理由 |
| --- | --- | --- |
| `belongs_to` | `eager_load` | 1:1関連はJOINしても行数が増えない |
| `has_one` | `eager_load` | 1:1関連はJOINしても行数が増えない |
| `has_many` | `preload` | 1:N関連はJOINすると行数が増え非効率 |
| `has_many :through` | `preload` | 1:N関連と同様 |

---

## 実装パターン

### 正しい例

```ruby
# 1:1関連と1:N関連が混在する場合
Catalog
  .eager_load(:discontinuation)      # has_one → eager_load
  .preload(:prices, :pricing_rules)  # has_many → preload
  .find(params[:id])

# 1:1関連のみ
User.eager_load(:profile).find(params[:id])

# 1:N関連のみ
Post.preload(:comments, :tags).all

# ネストしたアソシエーション
Catalog
  .eager_load(discontinuation: :reason)  # 1:1 → 1:1 はeager_load
  .preload(prices: :discounts)           # 1:N → 1:N はpreload
```

### 避けるべき例

```ruby
# includes は使わない
Catalog.includes(:discontinuation, :prices).find(params[:id])
```

---

## 各メソッドの特性

### eager_load

- LEFT OUTER JOIN で1クエリで取得
- 1:1関連に適している
- 関連をWHERE句でフィルタリングする場合に必須

### preload

- 別クエリで関連を取得（IN句使用）
- 1:N関連に適している
- JOINによる行の重複を避けられる

### includes（非推奨）

- Rails が自動で eager_load/preload を選択
- クエリが状況により変わり予測困難
- 明示的な制御ができない

---

## 注意事項

### eager_load + has_many の問題

has_many に eager_load を使用すると、JOINにより行が重複し `DISTINCT` が必要になる。
ページネーション時にスロークエリの原因となる。

### preload + 大量レコードの問題

大量のレコードを取得する場合、IN句が巨大になる可能性がある。
必要に応じて `find_each` や `in_batches` と組み合わせる。

### WHERE句で関連テーブルを参照する場合

関連テーブルの値で絞り込む場合は `eager_load` が必須。

```ruby
# 正しい例
Catalog.eager_load(:discontinuation)
       .where(discontinuations: { active: true })

# 動作しない例（preloadは別クエリのためWHERE句で参照不可）
Catalog.preload(:discontinuation)
       .where(discontinuations: { active: true })
```

---

## N+1検出

### strict_loading（Rails 6.1+）

開発環境でN+1クエリを検出するには `strict_loading` を活用する。

```ruby
# モデル単位で有効化
class Catalog < ApplicationRecord
  self.strict_loading_by_default = true
end

# クエリ単位で有効化
Catalog.strict_loading.find(params[:id])
```

eager loadingが不足している場合、`ActiveRecord::StrictLoadingViolationError` が発生する。

---

## 参考

- [ActiveRecordのincludesは使わずにpreloadとeager_loadを使い分ける理由](https://moneyforward-dev.jp/entry/2019/04/02/activerecord-includes-preload-eagerload/)
