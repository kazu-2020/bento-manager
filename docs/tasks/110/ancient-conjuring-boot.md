# Issue #110: 販売先詳細画面に日次販売個数の折れ線グラフを追加する

## Context

販売先詳細画面（`/locations/:id`）にはすでに「販売履歴」セクションのプレースホルダーが用意されている（`has_sales_history?` が常に `false`）。このプレースホルダーを実装に置き換え、直近1ヶ月の日次販売個数を職員/市民の2本線で折れ線グラフ表示する。ユーザーは50代の販売員のため、見やすさに配慮する。

## 設計方針

- **Chartkick** gem + **Chart.js** で描画（ERB ヘルパー1行でグラフ表示、Stimulus コントローラ不要）
- 集計メソッドは **Location モデル** に配置（Rails の規約に沿い、has_many :sales の集計は Location の責務）
- SalesChart を **独立した ViewComponent** として切り出し（既存パターンに準拠）
- `has_sales_history?` は EXISTS クエリで判定（高速、チャートデータ取得とは分離）
- SQL の `GROUP BY` で集計（メモリ上で全レコード展開しない）
- `group(:customer_type)` のキーは文字列（`"staff"`, `"citizen"`）で参照（Rails 7+ の enum 挙動）
- 既存のダミーセクション（販売履歴・在庫状況の 2 カラムグリッド）を削除し、グラフセクションを全幅で配置

## 変更ファイル一覧

### 新規作成

| ファイル | 概要 |
|---|---|
| `app/views/components/locations/sales_chart/component.rb` | グラフ用 ViewComponent |
| `app/views/components/locations/sales_chart/component.html.erb` | Chartkick `line_chart` ヘルパー呼び出し |
| `app/views/components/locations/sales_chart/component.yml` | i18n |
| `test/components/locations/sales_chart_component_test.rb` | コンポーネントテスト |
| `test/models/location_daily_sales_quantity_test.rb` | 集計メソッドテスト |

### 変更

| ファイル | 変更内容 |
|---|---|
| `Gemfile` | `chartkick` gem 追加 |
| `package.json` | `chartkick` + `chart.js` 追加 |
| `app/frontend/entrypoints/application.js` | `import "chartkick/chart.js"` 追加 |
| `app/models/location.rb` | `daily_sales_quantity` メソッド追加 |
| `app/views/components/locations/show/component.rb` | `has_sales_history?` を実データ判定に変更、`has_inventory?` 削除 |
| `app/views/components/locations/show/component.html.erb` | ダミーグリッド削除、SalesChart コンポーネント呼び出し |
| `app/views/components/locations/show/component.yml` | 在庫関連 i18n 削除 |
| `test/components/locations/show_component_test.rb` | 在庫関連テスト削除、グラフ表示テスト追加 |

## 実装詳細

### Step 1: Chartkick + Chart.js インストール

```bash
bundle add chartkick
npm install chartkick chart.js
```

`app/frontend/entrypoints/application.js` に追加:

```javascript
import "chartkick/chart.js"
```

<!-- dig-plan で追記 -->
**Vite 動作検証**: インストール後に `bin/dev` でサーバーを起動し、任意のページで JS エラーが出ないことを確認する。Vite で動作しない場合は Chartkick を外し、Chart.js + 自作 Stimulus コントローラ方式にフォールバックする。

**バンドルサイズ**: `application.js` への追加により Chart.js (~70KB gzip) が全ページで読み込まれるが、小規模アプリのため許容する。

### Step 2: Location モデルに集計メソッド追加

`app/models/location.rb` に追加:

```ruby
def daily_sales_quantity(period: 1.month)
  sales
    .completed
    .where(sale_datetime: period.ago.beginning_of_day..)
    .joins(:items)
    .group(Arel.sql("DATE(sale_datetime)"), :customer_type)
    .sum("sale_items.quantity")
  # => { ["2026-02-01", "staff"] => 5, ["2026-02-01", "citizen"] => 3, ... }
end
```

- `idx_sales_location_datetime` インデックスを活用
- SQLite3 の `DATE()` は `YYYY-MM-DD` 形式を返す

### Step 3: SalesChart ViewComponent 作成

**component.rb** - location を受け取り、Chartkick 用のデータ形式に整形:

```ruby
module Locations
  module SalesChart
    class Component < Application::Component
      def initialize(location:)
        @location = location
      end

      def chart_data
        @chart_data ||= build_chart_data
      end

      private

      def build_chart_data
        raw = @location.daily_sales_quantity
        date_range = (1.month.ago.to_date..Date.current)

        [
          { name: t(".staff_label"),   data: date_range.map { |d| [d, raw[[d.to_s, "staff"]] || 0] }.to_h },
          { name: t(".citizen_label"), data: date_range.map { |d| [d, raw[[d.to_s, "citizen"]] || 0] }.to_h }
        ]
      end
    end
  end
end
```

**component.html.erb** - Chartkick ヘルパー1行:

```erb
<%= helpers.line_chart chart_data,
      suffix: "個", ytitle: t(".y_axis_label"),
      colors: ["#4f46e5", "#059669"], legend: "top",
      height: "300px",
      library: { scales: { y: { beginAtZero: true, ticks: { stepSize: 1, precision: 0 } } } } %>
```

**component.yml**:

```yaml
ja:
  staff_label: 職員
  citizen_label: 市民
  y_axis_label: 販売個数
```

### Step 4: Show::Component 修正

**component.rb**:

- `has_inventory?` メソッドを削除
- `has_sales_history?` を実データ判定に変更:

```ruby
def has_sales_history?
  return false unless location.persisted?
  location.sales.completed.exists?
end
```

`persisted?` ガード: 既存テストが `Location.new(id: 1, ...)` を使っているため、未永続化オブジェクトでの DB クエリを回避。

**component.html.erb** - ダミーの 2 カラムグリッド（販売履歴・在庫状況）を削除し、全幅のグラフセクションに置き換え:

```erb
<%# 販売履歴グラフ %>
<section class="<%= CARD_CLASSES %>" aria-labelledby="sales-history-heading">
  <div class="card-body">
    <h2 id="sales-history-heading" class="card-title text-lg">
      <%= t(".sections.sales_history") %>
    </h2>

    <% if has_sales_history? %>
      <%= component "locations/sales_chart", location: location %>
    <% else %>
      <div class="text-center py-8 text-base-content/50">
        <%= helpers.icon "catalog", size: :lg, extra_class: "mx-auto mb-2 opacity-50" %>
        <p class="text-sm"><%= t(".empty_states.no_sales") %></p>
      </div>
    <% end %>
  </div>
</section>
```

削除対象: `<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">` ブロック全体（在庫状況セクション含む）。
i18n: `sections.inventory` と `empty_states.no_inventory` を `component.yml` から削除。

### Step 5: テスト

**集計メソッドテスト** (`test/models/location_daily_sales_quantity_test.rb`):
- 販売先の直近1ヶ月の日次販売個数が顧客区分ごとに集計される
- 取り消された販売は集計に含まれない
- 1ヶ月より前の販売は集計に含まれない
- 販売データがない販売先は空のハッシュを返す

**コンポーネントテスト** (`test/components/locations/sales_chart_component_test.rb`):
- 販売データがある場合は Chartkick の chart 要素がレンダリングされる
- chart_data に職員・市民のデータが含まれる
- 直近1ヶ月分の日付データが全日分生成される

**Show Component テスト** (既存ファイルを修正):
- 在庫状況セクション関連のテスト・アサーションを削除（`inventory-heading`, `no_inventory` 等）
- 既存テスト: `Location.new` → `has_sales_history?` は false → empty state 表示（`persisted?` ガードにより既存テスト互換）
- 追加テスト: `locations(:city_hall)` + 販売データ作成 → グラフセクション表示

## 検証

1. `bin/rails test` - 全テスト通過
2. `bin/rubocop -a` - Lint 通過
3. ブラウザで `/locations/:id` にアクセスし、グラフが表示されることを目視確認（cmux-frontend-check スキルを使用）
4. Vite での Chartkick 動作確認（Step 1 完了後に `bin/dev` でサーバー起動して確認）
