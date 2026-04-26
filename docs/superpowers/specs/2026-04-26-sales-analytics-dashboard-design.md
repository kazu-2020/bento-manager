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

Turbo Frames の eager loading を活用し、画面のパーツごとにコントローラーを分割する。
各パーツは `<turbo-frame src="...">` で独立して読み込まれるため、コントローラーとビューが1対1で対応しシンプルになる。

```ruby
# config/routes.rb に追加

# 画面A: 顧客タイプ別 商品分析
resources :sales_analyses, only: [:index]  # ページシェル + フィルターバー
namespace :sales_analyses do
  resource :summary, only: [:show]         # KPI サマリーカード
  resource :ranking, only: [:show]         # Top5 ランキング
  resource :cross_table, only: [:show]     # クロス集計テーブル
end

# 画面B/C: 販売履歴
resources :sales_histories, only: [:index, :show]  # カレンダーヒートマップ(index) + 日別取引一覧(show)
namespace :sales_histories do
  resource :daily_detail, only: [:show]    # 日別詳細パネル（Turbo Frame）
end
```

| HTTP | パス | コントローラー | 用途 |
|------|------|--------------|------|
| GET | `/sales_analyses` | `SalesAnalysesController#index` | ページシェル + フィルターバー |
| GET | `/sales_analyses/summary` | `SalesAnalyses::SummariesController#show` | KPI サマリーカード |
| GET | `/sales_analyses/ranking` | `SalesAnalyses::RankingsController#show` | Top5 ランキング |
| GET | `/sales_analyses/cross_table` | `SalesAnalyses::CrossTablesController#show` | クロス集計テーブル |
| GET | `/sales_histories` | `SalesHistoriesController#index` | カレンダーヒートマップ + 月間サマリー |
| GET | `/sales_histories/daily_detail` | `SalesHistories::DailyDetailsController#show` | 日別詳細パネル |
| GET | `/sales_histories/:id` | `SalesHistoriesController#show` | 日別取引履歴（`:id` は日付文字列 `2026-04-25`）|

共通クエリパラメータ（全パーツで共有）:
- `period`（7/30/90）, `location_id`, `from`, `to`（期間指定時）
- デフォルト: `period=30`, `location_id` は最初の active な Location

画面B 固有:
- `sales_histories#index`: `month`（`2026-04` 形式）。デフォルトは当月
- `sales_histories/daily_detail#show`: `date`（`2026-04-25` 形式）。デフォルトは当日（当月の場合）または月末日
- `sales_histories#show`: `location_id`。不正な日付（パース不能、未来日）の場合は `sales_histories#index` にリダイレクト

### サイドバー

`Sidebar::Component` の `menu_items` に2項目を追加:

```ruby
MenuItem.new(path: helpers.sales_analyses_path, label: "売上分析", icon: :chart, path_prefix: "/sales_analyses"),
MenuItem.new(path: helpers.sales_histories_path, label: "販売履歴", icon: :calendar, path_prefix: "/sales_histories"),
```

配置順序: 販売 → **売上分析** → **販売履歴** → 配達場所 → カタログ → クーポン

## 画面A: 顧客タイプ別 商品分析

### コントローラー構成

Turbo Frames の eager loading により、ページシェルとパーツで独立したコントローラーを持つ。

| コントローラー | 役割 | PORO 呼び出し |
|--------------|------|-------------|
| `SalesAnalysesController#index` | ページシェル + フィルターバーを描画。Turbo Frame の `src` にフィルターパラメータを埋め込む | なし |
| `SalesAnalyses::SummariesController#show` | KPI サマリーカードを描画 | `AnalysisSummary#summary_by_customer_type` |
| `SalesAnalyses::RankingsController#show` | Top5 ランキングを描画 | `AnalysisSummary#ranking` |
| `SalesAnalyses::CrossTablesController#show` | クロス集計テーブルを描画 | `AnalysisSummary#cross_table` |

各パーツコントローラーは同じフィルターパラメータ（`period`, `location_id` 等）を受け取り、`Sales::AnalysisSummary` を初期化して必要なメソッドだけ呼ぶ。

### ViewComponent 構成

| コンポーネント | パス | 描画元コントローラー |
|--------------|------|-------------------|
| ページ全体 | `sales_analyses/index_page` | `SalesAnalysesController#index` |
| フィルターバー | `sales_analyses/filter_bar` | `SalesAnalysesController#index`（index_page 内）|
| KPI サマリー | `sales_analyses/summary_cards` | `SalesAnalyses::SummariesController#show` |
| Top5 ランキング | `sales_analyses/ranking` | `SalesAnalyses::RankingsController#show` |
| クロス集計 | `sales_analyses/cross_table` | `SalesAnalyses::CrossTablesController#show` |

### Turbo Frame 構成

```
SalesAnalysesController#index が描画するページシェル:
┌──────────────────────────────────────────────────────────┐
│  フィルターバー（期間・出店先）                               │
│  フィルター変更 → Turbo Drive でページ全体を再読み込み        │
│  → 各フレームの src が新しいパラメータで再構築される           │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  <turbo-frame id="summary"                               │
│    src="/sales_analyses/summary?period=30&location_id=1"> │
│    <ローディング表示>                                      │
│  </turbo-frame>                                          │
│                                                          │
│  <turbo-frame id="ranking"                               │
│    src="/sales_analyses/ranking?period=30&location_id=1"> │
│    <ローディング表示>                                      │
│  </turbo-frame>                                          │
│                                                          │
│  <turbo-frame id="cross_table"                           │
│    src="/sales_analyses/cross_table?period=30&...">      │
│    <ローディング表示>                                      │
│  </turbo-frame>                                          │
│                                                          │
└──────────────────────────────────────────────────────────┘

ブラウザが各フレームを並列にフェッチ → 各コントローラーが独立して応答
```

フィルター変更のフロー:
1. フィルターバーのリンク/フォームが `/sales_analyses?period=7&location_id=1` に Turbo Drive で遷移
2. `SalesAnalysesController#index` がページシェルを再描画（フレームの `src` が新パラメータで再構築）
3. ブラウザが各フレームの `src` を並列にフェッチ

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

### コントローラー構成

カレンダー本体と日別詳細パネルを別コントローラーに分割する。
カレンダーと月間サマリーは同じ月データに依存するため、`SalesHistoriesController#index` でまとめて描画する。

| コントローラー | 役割 | PORO 呼び出し |
|--------------|------|-------------|
| `SalesHistoriesController#index` | カレンダーヒートマップ + 月間サマリーを描画。日別詳細の Turbo Frame `src` を埋め込む | `HistoryCalendar#daily_totals`, `#monthly_summary` |
| `SalesHistories::DailyDetailsController#show` | 日別詳細パネルを描画 | `HistoryCalendar#daily_breakdown` |

### ViewComponent 構成

| コンポーネント | パス | 描画元コントローラー |
|--------------|------|-------------------|
| ページ全体 | `sales_histories/index_page` | `SalesHistoriesController#index` |
| カレンダーヒートマップ | `sales_histories/calendar_heatmap` | `SalesHistoriesController#index`（index_page 内）|
| 月間サマリー | `sales_histories/monthly_summary` | `SalesHistoriesController#index`（index_page 内）|
| 日別詳細パネル | `sales_histories/daily_detail_panel` | `SalesHistories::DailyDetailsController#show` |

### Turbo Frame 構成

```
SalesHistoriesController#index が描画:
┌──────────────────────────────────────────────────────────────┐
│  出店先フィルター + 月ナビゲーション（前月/次月/今月へ）          │
│  月変更 → Turbo Drive でページ全体を再読み込み                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─ カレンダーヒートマップ ──────────────┐  ┌──────────────┐  │
│  │  日 月 火 水 木 金 土                  │  │ <turbo-frame │  │
│  │  [1] [2] [3] ...                      │  │   id="daily" │  │
│  │  日付クリック → daily フレームの       │  │   src="..."> │  │
│  │  src を更新して再フェッチ              │  │              │  │
│  │                                       │  │  日別詳細     │  │
│  ├───────────────────────────────────────┤  │  パネル       │  │
│  │  月間サマリー                          │  │              │  │
│  │  合計 | 営業日 | 平均 | 最高           │  └──────────────┘  │
│  └───────────────────────────────────────┘                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘

日別詳細パネルは eager loading で初期表示、日付クリック時にフレーム再フェッチ
```

日付クリックのフロー:
1. カレンダーの日付セルがリンク（`data-turbo-frame="daily"`）
2. `/sales_histories/daily_detail?date=2026-04-25&location_id=1` をフェッチ
3. `daily` フレーム内のみ更新（ページ全体はリロードしない）

月変更のフロー:
1. 前月/次月リンクが `/sales_histories?month=2026-03&location_id=1` に Turbo Drive で遷移
2. ページ全体が再描画（カレンダー + 日別詳細フレームの src 両方が更新）

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
| `SalesAnalysesController` | コントローラーテスト | ステータスコード、フィルターパラメータのデフォルト値 |
| `SalesAnalyses::SummariesController` | コントローラーテスト | Turbo Frame レスポンス、フィルターパラメータの受け渡し |
| `SalesAnalyses::RankingsController` | コントローラーテスト | Turbo Frame レスポンス、フィルターパラメータの受け渡し |
| `SalesAnalyses::CrossTablesController` | コントローラーテスト | Turbo Frame レスポンス、フィルターパラメータの受け渡し |
| `SalesHistoriesController` | コントローラーテスト | index/show のステータスコード、不正な日付パラメータのハンドリング |
| `SalesHistories::DailyDetailsController` | コントローラーテスト | Turbo Frame レスポンス、日付パラメータの受け渡し |
| ViewComponent | コンポーネントテスト | 各コンポーネントのレンダリング、表示内容の正しさ |

PORO のテストは実際の DB にデータを投入して検証する（mock 不使用）。

## I18n

`config/locales/ja.yml` に以下のキーを追加:

ViewComponent の i18n（`components.` プレフィックス配下）:
- `sales_analyses.index_page.*` — ページタイトル、説明
- `sales_analyses.filter_bar.*` — フィルターラベル、期間選択肢
- `sales_analyses.summary_cards.*` — KPI カードのラベル
- `sales_analyses.ranking.*` — ランキングのタイトル、ヘッダー
- `sales_analyses.cross_table.*` — クロス集計のヘッダー
- `sales_histories.index_page.*` — カレンダーページのタイトル、説明
- `sales_histories.calendar_heatmap.*` — 曜日名、月ナビゲーション
- `sales_histories.monthly_summary.*` — 月間サマリーのラベル
- `sales_histories.daily_detail_panel.*` — 詳細パネルのラベル
- `sales_histories.show_page.*` — 取引一覧ページタイトル、パンくず
- `sales_histories.daily_summary.*` — 日次サマリーのラベル
- `sales_histories.transaction_table.*` — テーブルヘッダー

## ファイル一覧

### 新規作成

```
# コントローラー（画面A: 売上分析）
app/controllers/sales_analyses_controller.rb
app/controllers/sales_analyses/summaries_controller.rb
app/controllers/sales_analyses/rankings_controller.rb
app/controllers/sales_analyses/cross_tables_controller.rb

# コントローラー（画面B/C: 販売履歴）
app/controllers/sales_histories_controller.rb
app/controllers/sales_histories/daily_details_controller.rb

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
test/controllers/sales_analyses/summaries_controller_test.rb
test/controllers/sales_analyses/rankings_controller_test.rb
test/controllers/sales_analyses/cross_tables_controller_test.rb
test/controllers/sales_histories_controller_test.rb
test/controllers/sales_histories/daily_details_controller_test.rb
```

### 既存ファイル編集

```
config/routes.rb — ルート追加
app/models/sale.rb — スコープ追加（in_period, at_location）
app/views/components/sidebar/component.rb — メニュー項目追加
config/locales/ja.yml — I18n キー追加
```
