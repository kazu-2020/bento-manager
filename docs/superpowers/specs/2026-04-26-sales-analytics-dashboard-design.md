# 売上分析ダッシュボード拡張 設計書

## 概要

お弁当屋さんの訪問販売データを分析するための3画面を新規実装する。
顧客タイプ（職員/一般）ごとの商品人気を把握し、過去の販売履歴をカレンダー形式で振り返れるようにする。

### 背景

- 現在は当日の販売履歴一覧と、Location 詳細ページ内の売上数折れ線グラフのみ
- 「どの弁当がどの顧客層に人気か」を把握する手段がない
- 過去の販売を月単位で振り返る機能がない

### 利用者

- お母さん（オーナー兼販売スタッフ）。現在唯一の利用者
- PC ブラウザでの閲覧を想定

## スコープ

| 画面 | 概要 |
|------|------|
| A. 顧客タイプ別 商品分析 | 期間・出店先を指定し、職員/一般それぞれの人気商品 Top5 とクロス集計を表示 |
| B. 販売履歴 カレンダーヒートマップ | 月別カレンダーで日ごとの売上金額を色の濃淡で表示。日付クリックで商品別内訳を表示 |
| C. 日別取引履歴 | カレンダーから遷移し、特定日の全取引を一覧表示 |

### スコープ外

- ダッシュボード（当日状況）画面
- 商品ドリルダウン画面
- 売上分析ヒートマップ（曜日×気温帯）画面
- モバイル対応

## アーキテクチャ

### 技術選定

| 要素 | 選定 | 理由 |
|------|------|------|
| チャート | Chartkick（既存）| ランキング等の標準的なグラフに適用。導入済み |
| カレンダーヒートマップ | ViewComponent + Tailwind CSS | Chartkick にカレンダーヒートマップがないため自前構築 |
| フィルター更新 | Turbo Frames | ページ全体のリロードなしで分析結果を部分更新 |
| 集計ロジック | PORO（`Sales::` 名前空間）| コントローラーを薄く保ち、集計ロジックを単体テスト可能にする |
| CSS | daisyUI + Tailwind（既存）| 既存テーマ caramellatte を活用 |

### ルーティング

```ruby
# config/routes.rb に追加
resources :sales_analyses, only: [:index]
resources :sales_histories, only: [:index, :show]
```

| HTTP | パス | アクション | 用途 |
|------|------|-----------|------|
| GET | `/sales_analyses` | `SalesAnalysesController#index` | 顧客タイプ別 商品分析 |
| GET | `/sales_histories` | `SalesHistoriesController#index` | カレンダーヒートマップ |
| GET | `/sales_histories/:id` | `SalesHistoriesController#show` | 日別取引履歴（`:id` は日付文字列 `2026-04-25`）|

クエリパラメータ:
- `sales_analyses`: `period`（7/30/90）, `location_id`, `from`, `to`（期間指定時）
  - デフォルト: `period=30`, `location_id` は最初の active な Location
- `sales_histories#index`: `month`（`2026-04` 形式）, `location_id`, `date`（選択日）
  - デフォルト: `month` は当月、`location_id` は最初の active な Location、`date` は当日（当月の場合）または月末日
- `sales_histories#show`: `location_id`
  - 不正な日付（パース不能、未来日）の場合は `sales_histories#index` にリダイレクト

### サイドバー

`Sidebar::Component` の `menu_items` に2項目を追加:

```ruby
MenuItem.new(path: helpers.sales_analyses_path, label: "売上分析", icon: :chart, path_prefix: "/sales_analyses"),
MenuItem.new(path: helpers.sales_histories_path, label: "販売履歴", icon: :calendar, path_prefix: "/sales_histories"),
```

配置順序: 販売 → **売上分析** → **販売履歴** → 配達場所 → カタログ → クーポン

## 画面A: 顧客タイプ別 商品分析

### コントローラー

`SalesAnalysesController#index`:
- クエリパラメータからフィルター条件を解析
- `Sales::AnalysisSummary` を初期化し、集計結果をコンポーネントに渡す
- Turbo Frame リクエスト時は結果部分のみレンダリング

### ViewComponent 構成

| コンポーネント | パス | 役割 |
|--------------|------|------|
| ページ全体 | `sales_analyses/index_page` | レイアウト、フィルターと結果の配置 |
| フィルターバー | `sales_analyses/filter_bar` | 期間（過去7日/30日/90日/期間指定）と出店先の選択 |
| KPI サマリー | `sales_analyses/summary_cards` | 総販売数・関係者・一般の3カード |
| Top5 ランキング | `sales_analyses/ranking` | 職員人気 Top5 / 一般人気 Top5（テーブル形式）|
| クロス集計 | `sales_analyses/cross_table` | 商品×顧客タイプの集計テーブル |

### Turbo Frame 構成

```
┌─ フィルターバー（期間・出店先）────────────────────┐
│  Turbo Frame: "sales_analysis_filters"             │
│  → GET /sales_analyses?period=30&location_id=1     │
└────────────────────────────────────────────────────┘
       ↓ src 属性で下記フレームを更新
┌─ 分析結果 ─────────────────────────────────────────┐
│  Turbo Frame: "sales_analysis_results"             │
│  ├── KPI サマリーカード                               │
│  ├── Top5 ランキング（職員 / 一般）                    │
│  └── クロス集計テーブル                                │
└────────────────────────────────────────────────────┘
```

### KPI サマリーカード

| カード | 表示内容 |
|--------|---------|
| 総販売数 | 合計個数、合計金額 |
| 関係者（職員）| 職員の販売個数、構成比（%）、平均単価 |
| 一般 | 一般の販売個数、構成比（%）、平均単価 |

### Top5 ランキング

- 職員/一般で左右に並べて表示
- 各行: 順位、商品名、販売個数、売上金額
- 顧客タイプごとに `Sales::AnalysisSummary#ranking` で取得

### クロス集計テーブル

| 列 | 内容 |
|----|------|
| 商品 | 商品名 |
| 合計 | 全顧客タイプの販売個数合計 |
| 構成比 | 全体に対する割合 |
| 関係者 | 職員の販売個数 |
| 一般 | 一般の販売個数 |
| 職員比率 | 関係者 / 合計 |

## 画面B: 販売履歴 カレンダーヒートマップ

### コントローラー

`SalesHistoriesController#index`:
- クエリパラメータから月・出店先・選択日を解析
- `Sales::HistoryCalendar` を初期化
- 月ナビゲーション（前月/次月/今月へ）

### ViewComponent 構成

| コンポーネント | パス | 役割 |
|--------------|------|------|
| ページ全体 | `sales_histories/index_page` | レイアウト（カレンダー + 詳細パネル）|
| カレンダーヒートマップ | `sales_histories/calendar_heatmap` | HTML テーブルで月カレンダー、売上金額で色の濃淡 |
| 月間サマリー | `sales_histories/monthly_summary` | 月合計・営業日・1日平均・最高日 |
| 日別詳細パネル | `sales_histories/daily_detail_panel` | 選択日の売上・販売数・商品別内訳 |

### Turbo Frame 構成

```
┌─ カレンダー + サマリー ────────────────────────────┐
│  Turbo Frame: "sales_history_calendar"             │
│  ├── 月ナビゲーション（前月/次月）                     │
│  ├── カレンダーヒートマップ                            │
│  └── 月間サマリー                                    │
└────────────────────────────────────────────────────┘

┌─ 日別詳細パネル ───────────────────────────────────┐
│  Turbo Frame: "sales_history_daily_detail"         │
│  ├── 日付、売上、販売数                               │
│  ├── 商品別内訳（関係者/一般の棒グラフ）               │
│  └── 「この日の取引履歴を全件表示」リンク              │
└────────────────────────────────────────────────────┘
```

日付クリック時: `daily_detail` フレームのみ更新
月変更時: `calendar` フレーム全体を更新

### ヒートマップの色分け

売上金額を5段階に分類。色はプロジェクトのブラウン系テーマに合わせる。

| レベル | 条件 | 色 |
|--------|------|-----|
| 0 | 営業なし | 空白（セルなし）|
| 1 | 最低〜20パーセンタイル | 最も薄い（`bg-amber-100` 相当）|
| 2 | 20〜40パーセンタイル | やや薄い |
| 3 | 40〜60パーセンタイル | 中間 |
| 4 | 60〜80パーセンタイル | やや濃い |
| 5 | 80パーセンタイル〜最高 | 最も濃い |

パーセンタイルは当月の営業日データから動的に算出する。Tailwind のクラス名は文字列リテラルでマッピング（動的生成禁止ルール準拠）。

### 月間サマリー

| 項目 | 算出方法 |
|------|---------|
| 月合計 | 月内の `Sale.completed` の `final_amount` 合計 |
| 営業日 | 売上が1件以上ある日数 |
| 1日平均 | 月合計 / 営業日 |
| 最高日 | 最も売上が高い日とその金額 |

### 日別詳細パネル

- 売上合計（`final_amount` の合計）
- 販売個数（`SaleItem.quantity` の合計）
- 商品別内訳: 商品名、関係者個数、一般個数、合計個数
- 内訳の棒グラフは CSS（`div` の幅）で表現。Chart.js は使わない
- 「この日の取引履歴を全件表示」→ `sales_histories/:date?location_id=X` へリンク

## 画面C: 日別取引履歴

### コントローラー

`SalesHistoriesController#show`:
- `params[:id]` から日付を解析（`Date.parse`）
- `params[:location_id]` で出店先指定
- `Sale` を `eager_load(:employee).preload(items: :catalog)` で取得
- `voided` の取引も含めて表示

### ViewComponent 構成

| コンポーネント | パス | 役割 |
|--------------|------|------|
| ページ全体 | `sales_histories/show_page` | パンくずリスト + サマリー + 取引一覧 |
| 日次サマリー | `sales_histories/daily_summary` | 売上合計・取引件数・出店先 |
| 取引一覧テーブル | `sales_histories/transaction_table` | 時刻・顧客タイプ・商品・数量・金額 |

### 取引一覧の表示

| 列 | 内容 |
|----|------|
| 時刻 | `sale_datetime` のHH:MM |
| 顧客 | バッジ表示（関係者: ブラウン、一般: ブルー）|
| 商品 | SaleItem の商品名（複数の場合はカンマ区切り）|
| 数量 | SaleItem の quantity 合計 |
| 金額 | `final_amount` |

- `voided` の取引: グレーアウト + 「取消済」バッジ + 金額に取り消し線
- パンくず: 販売履歴 > 2026年4月 > 4月25日（土）
- 「カレンダーに戻る」リンク → `sales_histories_path(month: ..., location_id: ...)`

## データ層

### Sale モデルに追加するスコープ

```ruby
# app/models/sale.rb
scope :in_period, ->(from, to) { where(sale_datetime: from..to) }
scope :at_location, ->(location_id) { where(location_id: location_id) }
```

### Sales::AnalysisSummary（PORO）

画面Aの集計ロジックを担当する。

```ruby
# app/models/sales/analysis_summary.rb
module Sales
  class AnalysisSummary
    def initialize(location_id:, from:, to:)
      @location_id = location_id
      @from = from
      @to = to
    end

    # 顧客タイプ別の販売数・売上
    # @return [Hash] { "staff" => { qty: Integer, amount: Integer },
    #                   "citizen" => { qty: Integer, amount: Integer } }
    def summary_by_customer_type; end

    # 顧客タイプ別の商品ランキング
    # @param customer_type [String] "staff" or "citizen"
    # @param limit [Integer]
    # @return [Array<Hash>] [{ catalog_id: Integer, qty: Integer, amount: Integer }, ...]
    def ranking(customer_type:, limit: 5); end

    # 商品×顧客タイプ クロス集計
    # @return [Array<Hash>] [{ catalog_id: Integer, staff_qty: Integer,
    #                          citizen_qty: Integer, total: Integer }, ...]
    def cross_table; end

    private

    def base_scope
      Sale.completed
          .where(location_id: @location_id, sale_datetime: @from..@to)
    end
  end
end
```

集計クエリは `GROUP BY` + `SUM` パターン。`DATE()` を使う場合は JST オフセット（`DATE(col, '+09:00')`）を適用する。

Catalog 名の解決: 集計結果の `catalog_id` 配列から `Catalog.where(id: ids)` で別途取得（GROUP BY 結果に eager_load は不可能なため）。

### Sales::HistoryCalendar（PORO）

画面Bの集計ロジックを担当する。

```ruby
# app/models/sales/history_calendar.rb
module Sales
  class HistoryCalendar
    def initialize(location_id:, month:)
      @location_id = location_id
      @month = month  # Date（月初日）
    end

    # 日別売上合計（ヒートマップ用）
    # @return [Hash] { "2026-04-01" => 12500, "2026-04-02" => 14200, ... }
    def daily_totals; end

    # 月間サマリー
    # @return [Hash] { total: Integer, business_days: Integer,
    #                  daily_avg: Integer,
    #                  best_day: { date: String, amount: Integer } }
    def monthly_summary; end

    # 特定日の商品別内訳（日別詳細パネル用）
    # @param date [Date]
    # @return [Array<Hash>] [{ catalog_id: Integer, staff_qty: Integer,
    #                          citizen_qty: Integer, total: Integer }, ...]
    def daily_breakdown(date); end

    private

    def base_scope
      Sale.completed
          .where(location_id: @location_id,
                 sale_datetime: @month.beginning_of_day..@month.end_of_month.end_of_day)
    end
  end
end
```

`daily_totals` は `DATE(sale_datetime, '+09:00')` で GROUP BY し `final_amount` を SUM する。

## テスト方針

| 対象 | テスト種別 | 内容 |
|------|----------|------|
| `Sales::AnalysisSummary` | モデルテスト | 各集計メソッドの戻り値を検証。期間・出店先フィルタリング、空データ時の挙動 |
| `Sales::HistoryCalendar` | モデルテスト | daily_totals のキー/値、monthly_summary の各項目、daily_breakdown の内訳 |
| `SalesAnalysesController` | コントローラーテスト | ステータスコード、Turbo Frame レスポンス、フィルターパラメータの受け渡し |
| `SalesHistoriesController` | コントローラーテスト | index/show のステータスコード、不正な日付パラメータのハンドリング |
| ViewComponent | コンポーネントテスト | 各コンポーネントのレンダリング、表示内容の正しさ |

PORO のテストは実際の DB にデータを投入して検証する（mock 不使用）。

## I18n

`config/locales/ja.yml` に以下のキーを追加:

- `sales_analyses.index_page.*` — フィルターラベル、期間選択肢、セクションタイトル
- `sales_analyses.summary_cards.*` — KPI カードのラベル
- `sales_analyses.ranking.*` — ランキングのタイトル、ヘッダー
- `sales_analyses.cross_table.*` — クロス集計のヘッダー
- `sales_histories.index_page.*` — カレンダーページのタイトル、説明
- `sales_histories.calendar_heatmap.*` — 曜日名、月ナビゲーション
- `sales_histories.daily_detail_panel.*` — 詳細パネルのラベル
- `sales_histories.show_page.*` — 取引一覧のヘッダー
- `sales_histories.transaction_table.*` — テーブルヘッダー

## ファイル一覧

### 新規作成

```
# ルーティング（既存ファイル編集）
config/routes.rb

# コントローラー
app/controllers/sales_analyses_controller.rb
app/controllers/sales_histories_controller.rb

# PORO
app/models/sales/analysis_summary.rb
app/models/sales/history_calendar.rb

# ViewComponent（画面A: 売上分析）
app/views/components/sales_analyses/index_page/component.rb
app/views/components/sales_analyses/index_page/component.html.erb
app/views/components/sales_analyses/filter_bar/component.rb
app/views/components/sales_analyses/filter_bar/component.html.erb
app/views/components/sales_analyses/summary_cards/component.rb
app/views/components/sales_analyses/summary_cards/component.html.erb
app/views/components/sales_analyses/ranking/component.rb
app/views/components/sales_analyses/ranking/component.html.erb
app/views/components/sales_analyses/cross_table/component.rb
app/views/components/sales_analyses/cross_table/component.html.erb

# ViewComponent（画面B: カレンダーヒートマップ）
app/views/components/sales_histories/index_page/component.rb
app/views/components/sales_histories/index_page/component.html.erb
app/views/components/sales_histories/calendar_heatmap/component.rb
app/views/components/sales_histories/calendar_heatmap/component.html.erb
app/views/components/sales_histories/monthly_summary/component.rb
app/views/components/sales_histories/monthly_summary/component.html.erb
app/views/components/sales_histories/daily_detail_panel/component.rb
app/views/components/sales_histories/daily_detail_panel/component.html.erb

# ViewComponent（画面C: 日別取引履歴）
app/views/components/sales_histories/show_page/component.rb
app/views/components/sales_histories/show_page/component.html.erb
app/views/components/sales_histories/daily_summary/component.rb
app/views/components/sales_histories/daily_summary/component.html.erb
app/views/components/sales_histories/transaction_table/component.rb
app/views/components/sales_histories/transaction_table/component.html.erb

# テスト
test/models/sales/analysis_summary_test.rb
test/models/sales/history_calendar_test.rb
test/controllers/sales_analyses_controller_test.rb
test/controllers/sales_histories_controller_test.rb

# I18n
config/locales/ja.yml（既存ファイル編集）
```

### 既存ファイル編集

```
config/routes.rb — ルート追加
app/models/sale.rb — スコープ追加（in_period, at_location）
app/views/components/sidebar/component.rb — メニュー項目追加
config/locales/ja.yml — I18n キー追加
```
