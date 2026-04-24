# Codebase Investigator Memory

## プロジェクト概要
- Rails v8 + SQLite3
- 小さなお弁当屋の出張訪問販売支援アプリ
- 並列テスト: `parallelize(workers: :number_of_processors)`（10プロセス, `storage/test.sqlite3_0`～`_9`）

## 重要なアーキテクチャパターン

### テスト設定
- `fixtures :all` は使用しない。各テストクラスで必要な fixture のみを個別宣言
- shoulda-matchers + minitest-matchers_vaccine: `@subject` を `setup` 内で設定し `must matcher` で検証

### fixture の依存関係（外部キー）

`sales` テーブルは以下を参照（すべて NOT NULL または外部キー制約あり）:
- `locations.location_id` (NOT NULL + FK)
- `employees.employee_id` (nullable FK)
- `employees.voided_by_employee_id` (nullable FK)

`sales` を使うテストクラスは必ず `fixtures` に `:locations` と `:employees` を含める必要がある。

**過去の問題 (flaky test)**: 並列テストで `sales` fixture ロード時に `locations` が未ロードだと外部キー違反が発生する。詳細は `debugging.md` 参照。

## 既知の技術的負債

### fixtures の不完全な依存宣言 (2026-02-27 発見)
以下のテストクラスで `sales` fixture を使用しているが `:locations` / `:employees` が欠落:
- `test/models/refund_test.rb`: `fixtures :sales` のみ
- `test/models/sale_discount_test.rb`: `fixtures :sales, :discounts, :sale_discounts` のみ
- `test/models/sale_item_test.rb`: `fixtures :sales, :catalogs, :catalog_prices` のみ

修正: `:locations, :employees` を追加する。

## 追加発注機能 (additional_orders) の構造 (2026-02-28 調査)

### 「選択可能なお弁当」の絞り込みロジック
コントローラーの `set_inventories` で以下の条件を組み合わせる:

```ruby
@inventories = @location.today_inventories   # 当日 (inventory_date: Date.current) の在庫のみ
                        .eager_load(:catalog)
                        .merge(Catalog.where(category: :bento))  # category enum 0 = bento のみ
                        .order("catalogs.kana")
```

- `today_inventories`: Location の `has_many` に `where(inventory_date: Date.current)` スコープ
- `Catalog.where(category: :bento)`: サイドメニューを除外
- 在庫登録 (DailyInventory) が存在しない商品は表示されない

### 関連ファイル
- コントローラー: `app/controllers/pos/locations/additional_orders_controller.rb`
- モデル: `app/models/additional_order.rb`
- フォームオブジェクト: `app/models/additional_orders/order_form.rb`
- アイテムオブジェクト: `app/models/additional_orders/order_item.rb`
- ViewComponent 群: `app/views/components/pos/additional_orders/` 配下
- テスト: `test/controllers/pos/locations/additional_orders_controller_test.rb`, `test/models/additional_order_test.rb`

## Location の show ページと販売データ構造 (2026-02-28 調査)

### Location show ページ（管理用）
- ルート: `resources :locations, except: [:destroy]`
- コントローラー: `app/controllers/locations_controller.rb` (show はシンプル)
- ビュー: `app/views/locations/show.html.erb` → ViewComponent `locations/show` に委譲
- ViewComponent: `app/views/components/locations/show/component.rb`
  - `has_sales_history?` → ハードコード `false`（**未実装プレースホルダー**）
  - `has_inventory?` → ハードコード `false`（**未実装プレースホルダー**）
- テンプレート: 2グリッド構成（販売履歴セクション + 在庫状況セクション）、両方とも空実装

### 販売データのテーブル構造
- `sales` テーブル: location_id, sale_datetime, customer_type(staff/citizen), status(completed/voided), total_amount, final_amount
- `sale_items` テーブル: sale_id, catalog_id, catalog_price_id, quantity, unit_price, line_total, sold_at
- インデックス: `idx_sales_location_datetime` (location_id, sale_datetime) → 日次集計クエリに有効

### 「日次の販売個数」取得のデータフロー
1. `location.sales.where(sale_datetime: Date.current.all_day)` で当日の sales を取得
2. `.preload(items: :catalog)` で N+1 回避
3. `.partition(&:completed?)` で completed/voided に分割
4. `completed_sales.size` → 販売件数, `.sum(&:final_amount)` → 売上合計
5. 商品別個数は `items.sum(&:quantity)` or `items.group_by { |i| i.catalog }` で集計

### 既存の sales_history (POS 側)
- コントローラー: `app/controllers/pos/locations/sales_history_controller.rb`
- 当日売上のみ表示（`Date.current.all_day`）
- `calculate_daily_summary` がメモリ内集計: total_count, total_amount, voided_count
- ViewComponent: `app/views/components/pos/sales_history/` 配下

### グラフ・可視化ライブラリ
- **Gemfile にグラフ系 gem なし**
- **package.json にチャートライブラリなし**（Tailwind CSS + DaisyUI のみ）
- 現在の可視化: DailySummary コンポーネントが DaisyUI の `stats` ウィジェットで数値テキスト表示のみ
