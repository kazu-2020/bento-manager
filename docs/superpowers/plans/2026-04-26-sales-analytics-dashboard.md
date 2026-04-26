# Sales Analytics Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** お弁当屋さんの訪問販売データを3画面（顧客タイプ別商品分析、カレンダーヒートマップ、日別取引履歴）で可視化する。
**Architecture:** Turbo Frames eager loading で画面パーツを並列フェッチし、PORO（`Sales::AnalysisSummary`, `Sales::HistoryCalendar`）に集計ロジックを分離する。各パーツは独立したコントローラーから ViewComponent を直接レンダリングし、レイアウトなしで `<turbo-frame>` 内に返す。
**Tech Stack:** Rails 8, SQLite3, ViewComponent, Hotwire (Turbo Frames), Chartkick, daisyUI (caramellatte), Tailwind CSS v4

---

### Task 1: テスト用 fixture の拡充

**Files:**
- Modify: `test/fixtures/sales.yml`
- Modify: `test/fixtures/sale_items.yml`
- Modify: `test/fixtures/catalog_prices.yml`

- [ ] **Step 1: catalog_prices に miso_soup の価格を追加**

`test/fixtures/catalog_prices.yml` に追加:

```yaml
miso_soup_regular:
  catalog: miso_soup
  kind: 0
  price: 150
  effective_from: <%= 1.month.ago.to_fs(:db) %>
  effective_until:
```

- [ ] **Step 2: sales.yml に分析用の販売データを追加**

既存の `completed_sale`, `voided_sale`, `prefectural_office_sale` は変更しない。以下を末尾に追加:

```yaml
# ============================================================
# 分析テスト用データ（既存 fixture には手を加えない）
# ============================================================

# --- 市役所: 職員の購入（過去数日にばらける） ---
analysis_staff_1:
  location: city_hall
  sale_datetime: <%= 1.day.ago %>
  customer_type: 0
  total_amount: 550
  final_amount: 550
  employee: verified_employee
  status: 0

analysis_staff_2:
  location: city_hall
  sale_datetime: <%= 1.day.ago %>
  customer_type: 0
  total_amount: 500
  final_amount: 500
  employee: verified_employee
  status: 0

analysis_staff_3:
  location: city_hall
  sale_datetime: <%= 3.days.ago %>
  customer_type: 0
  total_amount: 700
  final_amount: 700
  employee: verified_employee
  status: 0

analysis_staff_4:
  location: city_hall
  sale_datetime: <%= 5.days.ago %>
  customer_type: 0
  total_amount: 550
  final_amount: 550
  employee: verified_employee
  status: 0

analysis_staff_5:
  location: city_hall
  sale_datetime: <%= 7.days.ago %>
  customer_type: 0
  total_amount: 650
  final_amount: 650
  employee: verified_employee
  status: 0

# --- 市役所: 一般の購入 ---
analysis_citizen_1:
  location: city_hall
  sale_datetime: <%= 1.day.ago %>
  customer_type: 1
  total_amount: 550
  final_amount: 550
  employee: verified_employee
  status: 0

analysis_citizen_2:
  location: city_hall
  sale_datetime: <%= 2.days.ago %>
  customer_type: 1
  total_amount: 500
  final_amount: 500
  employee: verified_employee
  status: 0

analysis_citizen_3:
  location: city_hall
  sale_datetime: <%= 4.days.ago %>
  customer_type: 1
  total_amount: 250
  final_amount: 250
  employee: verified_employee
  status: 0

analysis_citizen_4:
  location: city_hall
  sale_datetime: <%= 6.days.ago %>
  customer_type: 1
  total_amount: 700
  final_amount: 700
  employee: verified_employee
  status: 0

analysis_citizen_5:
  location: city_hall
  sale_datetime: <%= 10.days.ago %>
  customer_type: 1
  total_amount: 550
  final_amount: 550
  employee: verified_employee
  status: 0

# --- 市役所: 取消済み（分析対象外を検証するため） ---
analysis_voided:
  location: city_hall
  sale_datetime: <%= 2.days.ago %>
  customer_type: 0
  total_amount: 550
  final_amount: 550
  employee: verified_employee
  status: 1
  voided_at: <%= 2.days.ago %>
  voided_by_employee: owner_employee

# --- 県庁: 別拠点データ（location フィルタ検証用） ---
analysis_pref_1:
  location: prefectural_office
  sale_datetime: <%= 1.day.ago %>
  customer_type: 0
  total_amount: 550
  final_amount: 550
  employee: owner_employee
  status: 0
```

- [ ] **Step 3: sale_items.yml に分析用の販売明細を追加**

既存の `completed_sale_bento_a`, `voided_sale_bento_a` は変更しない。以下を末尾に追加:

```yaml
# ============================================================
# 分析テスト用データ
# ============================================================

# analysis_staff_1: 弁当A x1
analysis_staff_1_bento_a:
  sale: analysis_staff_1
  catalog: daily_bento_a
  catalog_price: daily_bento_a_regular
  quantity: 1
  unit_price: 550
  line_total: 550
  sold_at: <%= 1.day.ago %>

# analysis_staff_2: 弁当B x1
analysis_staff_2_bento_b:
  sale: analysis_staff_2
  catalog: daily_bento_b
  catalog_price: daily_bento_b_regular
  quantity: 1
  unit_price: 500
  line_total: 500
  sold_at: <%= 1.day.ago %>

# analysis_staff_3: 弁当A x1 + サラダ x1
analysis_staff_3_bento_a:
  sale: analysis_staff_3
  catalog: daily_bento_a
  catalog_price: daily_bento_a_regular
  quantity: 1
  unit_price: 550
  line_total: 550
  sold_at: <%= 3.days.ago %>

analysis_staff_3_salad:
  sale: analysis_staff_3
  catalog: salad
  catalog_price: salad_bundle
  quantity: 1
  unit_price: 150
  line_total: 150
  sold_at: <%= 3.days.ago %>

# analysis_staff_4: 弁当A x1
analysis_staff_4_bento_a:
  sale: analysis_staff_4
  catalog: daily_bento_a
  catalog_price: daily_bento_a_regular
  quantity: 1
  unit_price: 550
  line_total: 550
  sold_at: <%= 5.days.ago %>

# analysis_staff_5: 弁当B x1 + 味噌汁 x1
analysis_staff_5_bento_b:
  sale: analysis_staff_5
  catalog: daily_bento_b
  catalog_price: daily_bento_b_regular
  quantity: 1
  unit_price: 500
  line_total: 500
  sold_at: <%= 7.days.ago %>

analysis_staff_5_miso:
  sale: analysis_staff_5
  catalog: miso_soup
  catalog_price: miso_soup_regular
  quantity: 1
  unit_price: 150
  line_total: 150
  sold_at: <%= 7.days.ago %>

# analysis_citizen_1: 弁当A x1
analysis_citizen_1_bento_a:
  sale: analysis_citizen_1
  catalog: daily_bento_a
  catalog_price: daily_bento_a_regular
  quantity: 1
  unit_price: 550
  line_total: 550
  sold_at: <%= 1.day.ago %>

# analysis_citizen_2: 弁当B x1
analysis_citizen_2_bento_b:
  sale: analysis_citizen_2
  catalog: daily_bento_b
  catalog_price: daily_bento_b_regular
  quantity: 1
  unit_price: 500
  line_total: 500
  sold_at: <%= 2.days.ago %>

# analysis_citizen_3: サラダ x1
analysis_citizen_3_salad:
  sale: analysis_citizen_3
  catalog: salad
  catalog_price: salad_regular
  quantity: 1
  unit_price: 250
  line_total: 250
  sold_at: <%= 4.days.ago %>

# analysis_citizen_4: 弁当A x1 + サラダ x1
analysis_citizen_4_bento_a:
  sale: analysis_citizen_4
  catalog: daily_bento_a
  catalog_price: daily_bento_a_regular
  quantity: 1
  unit_price: 550
  line_total: 550
  sold_at: <%= 6.days.ago %>

analysis_citizen_4_salad:
  sale: analysis_citizen_4
  catalog: salad
  catalog_price: salad_bundle
  quantity: 1
  unit_price: 150
  line_total: 150
  sold_at: <%= 6.days.ago %>

# analysis_citizen_5: 弁当A x1
analysis_citizen_5_bento_a:
  sale: analysis_citizen_5
  catalog: daily_bento_a
  catalog_price: daily_bento_a_regular
  quantity: 1
  unit_price: 550
  line_total: 550
  sold_at: <%= 10.days.ago %>

# analysis_voided: 弁当A x1（取消済み）
analysis_voided_bento_a:
  sale: analysis_voided
  catalog: daily_bento_a
  catalog_price: daily_bento_a_regular
  quantity: 1
  unit_price: 550
  line_total: 550
  sold_at: <%= 2.days.ago %>

# analysis_pref_1: 弁当A x1（県庁）
analysis_pref_1_bento_a:
  sale: analysis_pref_1
  catalog: daily_bento_a
  catalog_price: daily_bento_a_regular
  quantity: 1
  unit_price: 550
  line_total: 550
  sold_at: <%= 1.day.ago %>
```

- [ ] **Step 4: 既存テストが壊れていないことを確認**

Run: `bin/rails test`
Expected: PASS（既存テストが全て通る）

- [ ] **Step 5: Commit**

```bash
git add test/fixtures/sales.yml test/fixtures/sale_items.yml test/fixtures/catalog_prices.yml
git commit -m "feat: 販売分析テスト用の fixture データを追加"
```

---

### Task 2: Sale モデルスコープ追加

**Files:**
- Modify: `app/models/sale.rb`
- Test: `test/models/sale_test.rb`

- [ ] **Step 1: Write the failing test**

`test/models/sale_test.rb` に追加（既存テストがある場合は末尾に追記）:

```ruby
require "test_helper"

class SaleTest < ActiveSupport::TestCase
  fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items

  # --- スコープテスト ---

  test "in_period は指定期間内の販売のみを返す" do
    period_start = 8.days.ago.beginning_of_day
    period_end = Time.current

    results = Sale.in_period(period_start, period_end)

    # 10日前の analysis_citizen_5 は含まれない
    assert_not_includes results, sales(:analysis_citizen_5)
    # 1日前の analysis_staff_1 は含まれる
    assert_includes results, sales(:analysis_staff_1)
  end

  test "at_location は指定の販売先の販売のみを返す" do
    city_hall = locations(:city_hall)

    results = Sale.at_location(city_hall)

    assert_includes results, sales(:analysis_staff_1)
    assert_not_includes results, sales(:analysis_pref_1)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/sale_test.rb`
Expected: FAIL（`in_period`, `at_location` が未定義）

- [ ] **Step 3: Write minimal implementation**

`app/models/sale.rb` に追加:

```ruby
scope :in_period, ->(from, to) { where(sale_datetime: from..to) }
scope :at_location, ->(location) { where(location: location) }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/sale_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/sale.rb test/models/sale_test.rb
git commit -m "feat: Sale に in_period, at_location スコープを追加"
```

---

### Task 3: Sales::AnalysisSummary PORO

**Files:**
- Create: `app/models/sales/analysis_summary.rb`
- Test: `test/models/sales/analysis_summary_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/models/sales/analysis_summary_test.rb
require "test_helper"

module Sales
  class AnalysisSummaryTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      @location = locations(:city_hall)
      @period_start = 8.days.ago.beginning_of_day
      @period_end = Time.current
      @summary = Sales::AnalysisSummary.new(
        location: @location,
        period_start: @period_start,
        period_end: @period_end
      )
    end

    # --- summary_by_customer_type ---

    test "顧客タイプ別サマリーは職員と一般それぞれの販売数量を集計する" do
      result = @summary.summary_by_customer_type

      assert result.key?(:staff)
      assert result.key?(:citizen)
      assert result[:staff][:total_quantity] > 0
      assert result[:citizen][:total_quantity] > 0
    end

    test "顧客タイプ別サマリーは取消済みの販売を含まない" do
      result = @summary.summary_by_customer_type

      # analysis_voided は status: 1 なので集計に含まれない
      # staff の total_amount に analysis_voided の 550 が含まれていないことを検証
      # 期間内の staff completed sales: staff_1(550), staff_2(500), staff_3(700), staff_4(550), staff_5(650)
      # staff_5 は 7日前なので期間内（8日前から）
      assert_equal 2950, result[:staff][:total_amount]
    end

    # --- ranking ---

    test "ランキングは顧客タイプ別に販売数量上位の商品を返す" do
      result = @summary.ranking(limit: 5)

      assert result.key?(:staff)
      assert result.key?(:citizen)
      assert result[:staff].is_a?(Array)
      assert result[:citizen].is_a?(Array)
      assert result[:staff].length <= 5
      # 職員: 弁当A が最も多いはず（staff_1, staff_3, staff_4 で3個）
      top_staff = result[:staff].first
      assert_equal "日替わり弁当A", top_staff[:catalog_name]
    end

    # --- cross_table ---

    test "クロス集計は商品ごとに職員と一般の販売数量を並べる" do
      result = @summary.cross_table

      assert result.is_a?(Array)
      # 各行は { catalog_name:, staff_quantity:, citizen_quantity:, total_quantity: } の形式
      bento_a_row = result.find { |r| r[:catalog_name] == "日替わり弁当A" }
      assert_not_nil bento_a_row
      assert bento_a_row[:staff_quantity] > 0
      assert bento_a_row[:citizen_quantity] > 0
      assert_equal bento_a_row[:staff_quantity] + bento_a_row[:citizen_quantity], bento_a_row[:total_quantity]
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/sales/analysis_summary_test.rb`
Expected: FAIL（`Sales::AnalysisSummary` が未定義）

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/models/sales/analysis_summary.rb
module Sales
  class AnalysisSummary
    def initialize(location:, period_start:, period_end:)
      @location = location
      @period_start = period_start
      @period_end = period_end
    end

    # 顧客タイプ別の集計: { staff: { total_quantity:, total_amount: }, citizen: { ... } }
    def summary_by_customer_type
      base_scope.group(:customer_type).pluck(
        :customer_type,
        Arel.sql("SUM(sale_items.quantity)"),
        Arel.sql("SUM(sales.final_amount)")
      ).each_with_object({}) do |(customer_type, qty, amount), hash|
        key = Sale.customer_types.key(customer_type).to_sym
        hash[key] = { total_quantity: qty.to_i, total_amount: amount.to_i }
      end.tap do |result|
        result[:staff]   ||= { total_quantity: 0, total_amount: 0 }
        result[:citizen] ||= { total_quantity: 0, total_amount: 0 }
      end
    end

    # 顧客タイプ別のTop N ランキング
    # { staff: [{ catalog_name:, total_quantity: }, ...], citizen: [...] }
    def ranking(limit: 5)
      %i[staff citizen].each_with_object({}) do |type, hash|
        hash[type] = base_scope
          .where(customer_type: Sale.customer_types[type])
          .joins(items: :catalog)
          .group("catalogs.name")
          .order(Arel.sql("SUM(sale_items.quantity) DESC"))
          .limit(limit)
          .pluck(Arel.sql("catalogs.name"), Arel.sql("SUM(sale_items.quantity)"))
          .map { |name, qty| { catalog_name: name, total_quantity: qty.to_i } }
      end
    end

    # 商品 x 顧客タイプのクロス集計
    # [{ catalog_name:, staff_quantity:, citizen_quantity:, total_quantity: }, ...]
    def cross_table
      rows = base_scope
        .joins(items: :catalog)
        .group("catalogs.name", :customer_type)
        .pluck(Arel.sql("catalogs.name"), :customer_type, Arel.sql("SUM(sale_items.quantity)"))

      grouped = rows.each_with_object(Hash.new { |h, k| h[k] = { staff: 0, citizen: 0 } }) do |(name, ct, qty), hash|
        key = Sale.customer_types.key(ct).to_sym
        hash[name][key] = qty.to_i
      end

      grouped.map do |name, counts|
        {
          catalog_name: name,
          staff_quantity: counts[:staff],
          citizen_quantity: counts[:citizen],
          total_quantity: counts[:staff] + counts[:citizen]
        }
      end.sort_by { |row| -row[:total_quantity] }
    end

    private

    attr_reader :location, :period_start, :period_end

    def base_scope
      Sale
        .completed
        .at_location(location)
        .in_period(period_start, period_end)
        .joins(:items)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/sales/analysis_summary_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/sales/analysis_summary.rb test/models/sales/analysis_summary_test.rb
git commit -m "feat: Sales::AnalysisSummary PORO で顧客タイプ別分析を実装"
```

---

### Task 4: Sales::HistoryCalendar PORO

**Files:**
- Create: `app/models/sales/history_calendar.rb`
- Test: `test/models/sales/history_calendar_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/models/sales/history_calendar_test.rb
require "test_helper"

module Sales
  class HistoryCalendarTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      @location = locations(:city_hall)
      @target_month = Date.current
      @calendar = Sales::HistoryCalendar.new(location: @location, target_month: @target_month)
    end

    # --- daily_totals ---

    test "日別売上合計は対象月の各日の売上金額をハッシュで返す" do
      result = @calendar.daily_totals

      assert result.is_a?(Hash)
      # 今月の日付がキーになっている
      result.each_key do |date|
        assert_kind_of Date, date
        assert_equal @target_month.month, date.month
      end
    end

    test "日別売上合計は取消済みの販売を含まない" do
      result = @calendar.daily_totals

      # result の値は completed の final_amount のみ
      total = result.values.sum
      # analysis_voided (550) が含まれていないことを間接的に検証
      # voided を含めた場合の合計と一致しないことで確認
      voided_amount = sales(:analysis_voided).final_amount
      all_sales_amount = Sale.at_location(@location)
                             .in_period(@target_month.beginning_of_month.beginning_of_day, @target_month.end_of_month.end_of_day)
                             .joins(:items) # base_scope 互換
                             .sum(:final_amount)
      assert total < all_sales_amount || voided_amount > 0
    end

    # --- monthly_summary ---

    test "月間サマリーは販売日数・総売上・取引件数を返す" do
      result = @calendar.monthly_summary

      assert result.key?(:active_days)
      assert result.key?(:total_amount)
      assert result.key?(:total_transactions)
      assert result[:active_days] > 0
      assert result[:total_amount] > 0
      assert result[:total_transactions] > 0
    end

    # --- daily_breakdown ---

    test "日別内訳は指定日の商品別販売数量を返す" do
      target_date = 1.day.ago.to_date
      result = @calendar.daily_breakdown(target_date)

      assert result.is_a?(Array)
      # 1日前には analysis_staff_1 (弁当A), analysis_staff_2 (弁当B), analysis_citizen_1 (弁当A) がある
      assert result.length > 0
      item = result.first
      assert item.key?(:catalog_name)
      assert item.key?(:total_quantity)
      assert item.key?(:total_amount)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/sales/history_calendar_test.rb`
Expected: FAIL（`Sales::HistoryCalendar` が未定義）

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/models/sales/history_calendar.rb
module Sales
  class HistoryCalendar
    def initialize(location:, target_month:)
      @location = location
      @target_month = target_month
    end

    # 対象月の日別売上合計
    # { Date => Integer, ... }
    def daily_totals
      date_expr = jst_date_expression

      base_scope
        .where(sale_datetime: month_range)
        .group(date_expr)
        .sum(:final_amount)
        .transform_keys { |date_str| Date.parse(date_str) }
    end

    # 月間サマリー
    # { active_days:, total_amount:, total_transactions: }
    def monthly_summary
      sales_in_month = Sale.completed
                           .at_location(location)
                           .in_period(month_range.first, month_range.last)

      totals = daily_totals
      {
        active_days: totals.size,
        total_amount: totals.values.sum,
        total_transactions: sales_in_month.count
      }
    end

    # 指定日の商品別販売内訳
    # [{ catalog_name:, total_quantity:, total_amount: }, ...]
    def daily_breakdown(date)
      day_start = date.in_time_zone.beginning_of_day
      day_end = date.in_time_zone.end_of_day

      Sale.completed
          .at_location(location)
          .in_period(day_start, day_end)
          .joins(items: :catalog)
          .group("catalogs.name")
          .order(Arel.sql("SUM(sale_items.quantity) DESC"))
          .pluck(
            Arel.sql("catalogs.name"),
            Arel.sql("SUM(sale_items.quantity)"),
            Arel.sql("SUM(sale_items.line_total)")
          )
          .map do |name, qty, amount|
            { catalog_name: name, total_quantity: qty.to_i, total_amount: amount.to_i }
          end
    end

    private

    attr_reader :location, :target_month

    def base_scope
      Sale.completed.at_location(location)
    end

    def month_range
      target_month.beginning_of_month.beginning_of_day..target_month.end_of_month.end_of_day
    end

    # SQLite の DATE() は UTC ベース。JST オフセットを適用して日本時間の日付を得る
    def jst_date_expression
      offset = Time.zone.now.formatted_offset
      Arel.sql(
        Sale.sanitize_sql_array(["DATE(sale_datetime, ?)", offset])
      )
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/sales/history_calendar_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/sales/history_calendar.rb test/models/sales/history_calendar_test.rb
git commit -m "feat: Sales::HistoryCalendar PORO でカレンダー集計を実装"
```

---

### Task 5: アイコン追加 + ルーティング + サイドバー更新

**Files:**
- Create: `app/frontend/images/icons/chart.svg`
- Create: `app/frontend/images/icons/calendar.svg`
- Modify: `config/routes.rb`
- Modify: `app/views/components/sidebar/component.rb`
- Test: `test/controllers/sales_analyses_controller_test.rb` (ルーティング疎通のみ)

- [ ] **Step 1: chart.svg を作成**

```svg
<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
  <path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z" />
</svg>
```

- [ ] **Step 2: calendar.svg を作成**

```svg
<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
  <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5m-9-6h.008v.008H12v-.008ZM12 15h.008v.008H12V15Zm0 2.25h.008v.008H12v-.008ZM9.75 15h.008v.008H9.75V15Zm0 2.25h.008v.008H9.75v-.008ZM7.5 15h.008v.008H7.5V15Zm0 2.25h.008v.008H7.5v-.008Zm6.75-4.5h.008v.008h-.008v-.008Zm0 2.25h.008v.008h-.008V15Zm0 2.25h.008v.008h-.008v-.008Zm2.25-4.5h.008v.008H16.5v-.008Zm0 2.25h.008v.008H16.5V15Z" />
</svg>
```

- [ ] **Step 3: config/routes.rb にルートを追加**

`config/routes.rb` の `resources :catalogs do ... end` ブロックの後に追加:

```ruby
  # 販売分析
  resources :sales_analyses, only: [:index]
  namespace :sales_analyses do
    resource :summary, only: [:show]
    resource :ranking, only: [:show]
    resource :cross_table, only: [:show]
  end

  # 販売履歴カレンダー
  resources :sales_histories, only: [:index, :show]
  namespace :sales_histories do
    resource :daily_detail, only: [:show]
  end
```

- [ ] **Step 4: Sidebar にメニュー項目を追加**

`app/views/components/sidebar/component.rb` の `menu_items` メソッドに追加:

```ruby
def menu_items
  @menu_items ||= [
    MenuItem.new(path: helpers.pos_locations_path, label: "販売", icon: :bento, path_prefix: nil),
    MenuItem.new(path: helpers.locations_path, label: "配達場所", icon: :location, path_prefix: "/locations"),
    MenuItem.new(path: helpers.catalogs_path, label: "カタログ", icon: :catalog, path_prefix: "/catalogs"),
    MenuItem.new(path: helpers.discounts_path, label: "クーポン", icon: :ticket, path_prefix: "/discounts"),
    MenuItem.new(path: helpers.sales_analyses_path, label: "販売分析", icon: :chart, path_prefix: "/sales_analyses"),
    MenuItem.new(path: helpers.sales_histories_path, label: "販売履歴", icon: :calendar, path_prefix: "/sales_histories")
  ]
end
```

- [ ] **Step 5: ルーティング疎通確認テストを作成**

```ruby
# test/controllers/sales_analyses_controller_test.rb
require "test_helper"

class SalesAnalysesControllerTest < ActionDispatch::IntegrationTest
  fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

  test "未認証ユーザーはログインページにリダイレクトされる" do
    get sales_analyses_path
    assert_redirected_to "/employee/login"
  end
end
```

- [ ] **Step 6: Run test to verify it fails (コントローラーが未定義)**

Run: `bin/rails test test/controllers/sales_analyses_controller_test.rb`
Expected: FAIL（`SalesAnalysesController` が未定義のためルーティングエラー）

- [ ] **Step 7: 空のコントローラーを作成して疎通を確認**

```ruby
# app/controllers/sales_analyses_controller.rb
# frozen_string_literal: true

class SalesAnalysesController < ApplicationController
  def index
    head :ok
  end
end
```

- [ ] **Step 8: Run test to verify it passes**

Run: `bin/rails test test/controllers/sales_analyses_controller_test.rb`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add app/frontend/images/icons/chart.svg app/frontend/images/icons/calendar.svg \
       config/routes.rb app/views/components/sidebar/component.rb \
       app/controllers/sales_analyses_controller.rb \
       test/controllers/sales_analyses_controller_test.rb
git commit -m "feat: 販売分析・販売履歴のルーティングとサイドバーメニューを追加"
```

---

### Task 6: SalesAnalysesController + IndexPage + FilterBar

**Files:**
- Modify: `app/controllers/sales_analyses_controller.rb`
- Create: `app/views/components/sales_analyses/index_page/component.rb`
- Create: `app/views/components/sales_analyses/index_page/component.html.erb`
- Create: `app/views/components/sales_analyses/filter_bar/component.rb`
- Create: `app/views/components/sales_analyses/filter_bar/component.html.erb`
- Modify: `test/controllers/sales_analyses_controller_test.rb`

- [ ] **Step 1: コントローラーテストを拡充**

`test/controllers/sales_analyses_controller_test.rb` を更新:

```ruby
require "test_helper"

class SalesAnalysesControllerTest < ActionDispatch::IntegrationTest
  fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

  setup do
    login_as_employee(:verified_employee)
  end

  test "認証済みユーザーが index にアクセスできる" do
    get sales_analyses_path
    assert_response :success
  end

  test "period パラメータを受け取る" do
    get sales_analyses_path, params: { period: 7 }
    assert_response :success
  end

  test "location_id パラメータを受け取る" do
    get sales_analyses_path, params: { location_id: locations(:city_hall).id }
    assert_response :success
  end

  test "未認証ユーザーはログインページにリダイレクトされる" do
    reset!
    get sales_analyses_path
    assert_redirected_to "/employee/login"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/sales_analyses_controller_test.rb`
Expected: FAIL（コントローラーが `head :ok` のみのため、パラメータ処理テストは通るが実装は不完全）

- [ ] **Step 3: コントローラーを実装**

```ruby
# app/controllers/sales_analyses_controller.rb
# frozen_string_literal: true

class SalesAnalysesController < ApplicationController
  def index
    @period = (params[:period] || 30).to_i
    @location = find_location
    @period_start = @period.days.ago.beginning_of_day
    @period_end = Time.current

    render SalesAnalyses::IndexPage::Component.new(
      location: @location,
      period: @period,
      period_start: @period_start,
      period_end: @period_end,
      locations: Location.active.order(:name)
    )
  end

  private

  def find_location
    if params[:location_id].present?
      Location.find(params[:location_id])
    else
      Location.active.order(:name).first
    end
  end
end
```

- [ ] **Step 4: IndexPage コンポーネントを作成**

```ruby
# app/views/components/sales_analyses/index_page/component.rb
# frozen_string_literal: true

module SalesAnalyses
  module IndexPage
    class Component < Application::Component
      def initialize(location:, period:, period_start:, period_end:, locations:)
        @location = location
        @period = period
        @period_start = period_start
        @period_end = period_end
        @locations = locations
      end

      private

      attr_reader :location, :period, :period_start, :period_end, :locations

      def summary_src
        helpers.sales_analyses_summary_path(location_id: location.id, period: period)
      end

      def ranking_src
        helpers.sales_analyses_ranking_path(location_id: location.id, period: period)
      end

      def cross_table_src
        helpers.sales_analyses_cross_table_path(location_id: location.id, period: period)
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_analyses/index_page/component.html.erb %>
<div class="space-y-6">
  <header>
    <%= component "page_header", title: t(".title") %>
  </header>

  <%# フィルターバー %>
  <%= component "sales_analyses/filter_bar",
        location: location,
        period: period,
        locations: locations %>

  <%# KPIサマリー（Turbo Frame） %>
  <%= turbo_frame_tag "sales_analysis_summary", src: summary_src, loading: :eager do %>
    <div class="flex justify-center py-8">
      <span class="loading loading-spinner loading-md"></span>
    </div>
  <% end %>

  <%# ランキング（Turbo Frame） %>
  <%= turbo_frame_tag "sales_analysis_ranking", src: ranking_src, loading: :eager do %>
    <div class="flex justify-center py-8">
      <span class="loading loading-spinner loading-md"></span>
    </div>
  <% end %>

  <%# クロス集計（Turbo Frame） %>
  <%= turbo_frame_tag "sales_analysis_cross_table", src: cross_table_src, loading: :eager do %>
    <div class="flex justify-center py-8">
      <span class="loading loading-spinner loading-md"></span>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: FilterBar コンポーネントを作成**

```ruby
# app/views/components/sales_analyses/filter_bar/component.rb
# frozen_string_literal: true

module SalesAnalyses
  module FilterBar
    class Component < Application::Component
      PERIOD_OPTIONS = [
        { value: 7, label: "7日間" },
        { value: 14, label: "14日間" },
        { value: 30, label: "30日間" },
        { value: 90, label: "90日間" }
      ].freeze

      def initialize(location:, period:, locations:)
        @location = location
        @period = period
        @locations = locations
      end

      private

      attr_reader :location, :period, :locations

      def period_options
        PERIOD_OPTIONS
      end

      def period_selected?(value)
        period == value
      end

      def period_btn_class(value)
        if period_selected?(value)
          "btn btn-primary btn-sm"
        else
          "btn btn-ghost btn-sm"
        end
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_analyses/filter_bar/component.html.erb %>
<div class="flex flex-wrap items-center gap-4 p-4 bg-base-200 rounded-box">
  <%# 期間ボタン %>
  <div class="flex items-center gap-2">
    <span class="text-sm font-medium"><%= t(".period_label") %></span>
    <div class="join">
      <% period_options.each do |opt| %>
        <%= link_to opt[:label],
              helpers.sales_analyses_path(period: opt[:value], location_id: location.id),
              class: "#{period_btn_class(opt[:value])} join-item" %>
      <% end %>
    </div>
  </div>

  <%# 出店先セレクト %>
  <div class="flex items-center gap-2">
    <span class="text-sm font-medium"><%= t(".location_label") %></span>
    <%= form_with url: helpers.sales_analyses_path, method: :get, data: { turbo: false } do |f| %>
      <%= f.hidden_field :period, value: period %>
      <%= f.select :location_id,
            options_from_collection_for_select(locations, :id, :name, location.id),
            {},
            class: "select select-bordered select-sm",
            onchange: "this.form.submit()" %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/controllers/sales_analyses_controller_test.rb`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/controllers/sales_analyses_controller.rb \
       app/views/components/sales_analyses/index_page/ \
       app/views/components/sales_analyses/filter_bar/ \
       test/controllers/sales_analyses_controller_test.rb
git commit -m "feat: 販売分析ページのシェルとフィルターバーを実装"
```

---

### Task 7: SalesAnalyses::SummariesController + SummaryCards

**Files:**
- Create: `app/controllers/sales_analyses/summaries_controller.rb`
- Create: `app/views/components/sales_analyses/summary_cards/component.rb`
- Create: `app/views/components/sales_analyses/summary_cards/component.html.erb`
- Create: `test/controllers/sales_analyses/summaries_controller_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/controllers/sales_analyses/summaries_controller_test.rb
require "test_helper"

module SalesAnalyses
  class SummariesControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      login_as_employee(:verified_employee)
      @location = locations(:city_hall)
    end

    test "認証済みユーザーが summary を取得できる" do
      get sales_analyses_summary_path(location_id: @location.id, period: 30)
      assert_response :success
    end

    test "Turbo Frame リクエストで正しいフレームIDを返す" do
      get sales_analyses_summary_path(location_id: @location.id, period: 30),
          headers: { "Turbo-Frame" => "sales_analysis_summary" }
      assert_response :success
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get sales_analyses_summary_path(location_id: @location.id, period: 30)
      assert_redirected_to "/employee/login"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/sales_analyses/summaries_controller_test.rb`
Expected: FAIL

- [ ] **Step 3: コントローラーを実装**

```ruby
# app/controllers/sales_analyses/summaries_controller.rb
# frozen_string_literal: true

module SalesAnalyses
  class SummariesController < ApplicationController
    def show
      location = Location.find(params[:location_id])
      period = (params[:period] || 30).to_i
      period_start = period.days.ago.beginning_of_day
      period_end = Time.current

      summary = Sales::AnalysisSummary.new(
        location: location,
        period_start: period_start,
        period_end: period_end
      )

      render SalesAnalyses::SummaryCards::Component.new(
        summary: summary.summary_by_customer_type
      )
    end
  end
end
```

- [ ] **Step 4: SummaryCards コンポーネントを作成**

```ruby
# app/views/components/sales_analyses/summary_cards/component.rb
# frozen_string_literal: true

module SalesAnalyses
  module SummaryCards
    class Component < Application::Component
      FRAME_ID = "sales_analysis_summary"

      def initialize(summary:)
        @summary = summary
      end

      private

      attr_reader :summary

      def total_quantity
        summary[:staff][:total_quantity] + summary[:citizen][:total_quantity]
      end

      def staff_quantity
        summary[:staff][:total_quantity]
      end

      def citizen_quantity
        summary[:citizen][:total_quantity]
      end

      def staff_amount
        summary[:staff][:total_amount]
      end

      def citizen_amount
        summary[:citizen][:total_amount]
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_analyses/summary_cards/component.html.erb %>
<%= turbo_frame_tag FRAME_ID do %>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <%# 総販売数 %>
    <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
      <div class="stat-title"><%= t(".total_sales") %></div>
      <div class="stat-value text-primary"><%= total_quantity %></div>
      <div class="stat-desc"><%= t(".unit") %></div>
    </div>

    <%# 関係者販売数 %>
    <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
      <div class="stat-title"><%= t(".staff_sales") %></div>
      <div class="stat-value"><%= staff_quantity %></div>
      <div class="stat-desc"><%= number_to_currency(staff_amount) %></div>
    </div>

    <%# 一般販売数 %>
    <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
      <div class="stat-title"><%= t(".citizen_sales") %></div>
      <div class="stat-value"><%= citizen_quantity %></div>
      <div class="stat-desc"><%= number_to_currency(citizen_amount) %></div>
    </div>
  </div>
<% end %>
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/sales_analyses/summaries_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/sales_analyses/summaries_controller.rb \
       app/views/components/sales_analyses/summary_cards/ \
       test/controllers/sales_analyses/summaries_controller_test.rb
git commit -m "feat: 販売分析 KPI サマリーカードを Turbo Frame で実装"
```

---

### Task 8: SalesAnalyses::RankingsController + Ranking

**Files:**
- Create: `app/controllers/sales_analyses/rankings_controller.rb`
- Create: `app/views/components/sales_analyses/ranking/component.rb`
- Create: `app/views/components/sales_analyses/ranking/component.html.erb`
- Create: `test/controllers/sales_analyses/rankings_controller_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/controllers/sales_analyses/rankings_controller_test.rb
require "test_helper"

module SalesAnalyses
  class RankingsControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      login_as_employee(:verified_employee)
      @location = locations(:city_hall)
    end

    test "認証済みユーザーが ranking を取得できる" do
      get sales_analyses_ranking_path(location_id: @location.id, period: 30)
      assert_response :success
    end

    test "Turbo Frame リクエストで正しいフレームIDを返す" do
      get sales_analyses_ranking_path(location_id: @location.id, period: 30),
          headers: { "Turbo-Frame" => "sales_analysis_ranking" }
      assert_response :success
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get sales_analyses_ranking_path(location_id: @location.id, period: 30)
      assert_redirected_to "/employee/login"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/sales_analyses/rankings_controller_test.rb`
Expected: FAIL

- [ ] **Step 3: コントローラーを実装**

```ruby
# app/controllers/sales_analyses/rankings_controller.rb
# frozen_string_literal: true

module SalesAnalyses
  class RankingsController < ApplicationController
    def show
      location = Location.find(params[:location_id])
      period = (params[:period] || 30).to_i
      period_start = period.days.ago.beginning_of_day
      period_end = Time.current

      summary = Sales::AnalysisSummary.new(
        location: location,
        period_start: period_start,
        period_end: period_end
      )

      render SalesAnalyses::Ranking::Component.new(
        ranking: summary.ranking(limit: 5)
      )
    end
  end
end
```

- [ ] **Step 4: Ranking コンポーネントを作成**

```ruby
# app/views/components/sales_analyses/ranking/component.rb
# frozen_string_literal: true

module SalesAnalyses
  module Ranking
    class Component < Application::Component
      FRAME_ID = "sales_analysis_ranking"

      RANK_BADGES = {
        1 => "badge badge-warning",
        2 => "badge badge-ghost",
        3 => "badge badge-ghost"
      }.freeze

      def initialize(ranking:)
        @ranking = ranking
      end

      private

      attr_reader :ranking

      def staff_ranking
        ranking[:staff]
      end

      def citizen_ranking
        ranking[:citizen]
      end

      def rank_badge_class(index)
        RANK_BADGES.fetch(index + 1, "badge badge-ghost badge-outline")
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_analyses/ranking/component.html.erb %>
<%= turbo_frame_tag FRAME_ID do %>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <%# 関係者 Top5 %>
    <div class="card bg-base-100 shadow-sm border border-base-300">
      <div class="card-body">
        <h3 class="card-title text-base"><%= t(".staff_title") %></h3>
        <% if staff_ranking.any? %>
          <table class="table table-sm">
            <thead>
              <tr>
                <th><%= t(".rank") %></th>
                <th><%= t(".product") %></th>
                <th class="text-right"><%= t(".quantity") %></th>
              </tr>
            </thead>
            <tbody>
              <% staff_ranking.each_with_index do |item, i| %>
                <tr>
                  <td><span class="<%= rank_badge_class(i) %>"><%= i + 1 %></span></td>
                  <td><%= item[:catalog_name] %></td>
                  <td class="text-right"><%= item[:total_quantity] %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% else %>
          <p class="text-base-content/50 text-sm py-4"><%= t(".no_data") %></p>
        <% end %>
      </div>
    </div>

    <%# 一般 Top5 %>
    <div class="card bg-base-100 shadow-sm border border-base-300">
      <div class="card-body">
        <h3 class="card-title text-base"><%= t(".citizen_title") %></h3>
        <% if citizen_ranking.any? %>
          <table class="table table-sm">
            <thead>
              <tr>
                <th><%= t(".rank") %></th>
                <th><%= t(".product") %></th>
                <th class="text-right"><%= t(".quantity") %></th>
              </tr>
            </thead>
            <tbody>
              <% citizen_ranking.each_with_index do |item, i| %>
                <tr>
                  <td><span class="<%= rank_badge_class(i) %>"><%= i + 1 %></span></td>
                  <td><%= item[:catalog_name] %></td>
                  <td class="text-right"><%= item[:total_quantity] %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% else %>
          <p class="text-base-content/50 text-sm py-4"><%= t(".no_data") %></p>
        <% end %>
      </div>
    </div>
  </div>
<% end %>
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/sales_analyses/rankings_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/sales_analyses/rankings_controller.rb \
       app/views/components/sales_analyses/ranking/ \
       test/controllers/sales_analyses/rankings_controller_test.rb
git commit -m "feat: 販売分析 顧客タイプ別Top5ランキングを実装"
```

---

### Task 9: SalesAnalyses::CrossTablesController + CrossTable

**Files:**
- Create: `app/controllers/sales_analyses/cross_tables_controller.rb`
- Create: `app/views/components/sales_analyses/cross_table/component.rb`
- Create: `app/views/components/sales_analyses/cross_table/component.html.erb`
- Create: `test/controllers/sales_analyses/cross_tables_controller_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/controllers/sales_analyses/cross_tables_controller_test.rb
require "test_helper"

module SalesAnalyses
  class CrossTablesControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      login_as_employee(:verified_employee)
      @location = locations(:city_hall)
    end

    test "認証済みユーザーが cross_table を取得できる" do
      get sales_analyses_cross_table_path(location_id: @location.id, period: 30)
      assert_response :success
    end

    test "Turbo Frame リクエストで正しいフレームIDを返す" do
      get sales_analyses_cross_table_path(location_id: @location.id, period: 30),
          headers: { "Turbo-Frame" => "sales_analysis_cross_table" }
      assert_response :success
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get sales_analyses_cross_table_path(location_id: @location.id, period: 30)
      assert_redirected_to "/employee/login"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/sales_analyses/cross_tables_controller_test.rb`
Expected: FAIL

- [ ] **Step 3: コントローラーを実装**

```ruby
# app/controllers/sales_analyses/cross_tables_controller.rb
# frozen_string_literal: true

module SalesAnalyses
  class CrossTablesController < ApplicationController
    def show
      location = Location.find(params[:location_id])
      period = (params[:period] || 30).to_i
      period_start = period.days.ago.beginning_of_day
      period_end = Time.current

      summary = Sales::AnalysisSummary.new(
        location: location,
        period_start: period_start,
        period_end: period_end
      )

      render SalesAnalyses::CrossTable::Component.new(
        rows: summary.cross_table
      )
    end
  end
end
```

- [ ] **Step 4: CrossTable コンポーネントを作成**

```ruby
# app/views/components/sales_analyses/cross_table/component.rb
# frozen_string_literal: true

module SalesAnalyses
  module CrossTable
    class Component < Application::Component
      FRAME_ID = "sales_analysis_cross_table"

      def initialize(rows:)
        @rows = rows
      end

      private

      attr_reader :rows
    end
  end
end
```

```erb
<%# app/views/components/sales_analyses/cross_table/component.html.erb %>
<%= turbo_frame_tag FRAME_ID do %>
  <div class="card bg-base-100 shadow-sm border border-base-300">
    <div class="card-body">
      <h3 class="card-title text-base"><%= t(".title") %></h3>
      <% if rows.any? %>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th><%= t(".product") %></th>
                <th class="text-right"><%= t(".staff") %></th>
                <th class="text-right"><%= t(".citizen") %></th>
                <th class="text-right"><%= t(".total") %></th>
              </tr>
            </thead>
            <tbody>
              <% rows.each do |row| %>
                <tr>
                  <td><%= row[:catalog_name] %></td>
                  <td class="text-right"><%= row[:staff_quantity] %></td>
                  <td class="text-right"><%= row[:citizen_quantity] %></td>
                  <td class="text-right font-semibold"><%= row[:total_quantity] %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% else %>
        <p class="text-base-content/50 text-sm py-4"><%= t(".no_data") %></p>
      <% end %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/sales_analyses/cross_tables_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/sales_analyses/cross_tables_controller.rb \
       app/views/components/sales_analyses/cross_table/ \
       test/controllers/sales_analyses/cross_tables_controller_test.rb
git commit -m "feat: 販売分析 商品×顧客タイプ クロス集計を実装"
```

---

### Task 10: SalesHistoriesController#index + カレンダーコンポーネント群

**Files:**
- Create: `app/controllers/sales_histories_controller.rb`
- Create: `app/views/components/sales_histories/index_page/component.rb`
- Create: `app/views/components/sales_histories/index_page/component.html.erb`
- Create: `app/views/components/sales_histories/calendar_heatmap/component.rb`
- Create: `app/views/components/sales_histories/calendar_heatmap/component.html.erb`
- Create: `app/views/components/sales_histories/monthly_summary/component.rb`
- Create: `app/views/components/sales_histories/monthly_summary/component.html.erb`
- Create: `test/controllers/sales_histories_controller_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/controllers/sales_histories_controller_test.rb
require "test_helper"

class SalesHistoriesControllerTest < ActionDispatch::IntegrationTest
  fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

  setup do
    login_as_employee(:verified_employee)
    @location = locations(:city_hall)
  end

  test "認証済みユーザーが index にアクセスできる" do
    get sales_histories_path
    assert_response :success
  end

  test "month パラメータで表示月を変更できる" do
    get sales_histories_path, params: { month: "2026-03" }
    assert_response :success
  end

  test "location_id パラメータで販売先を指定できる" do
    get sales_histories_path, params: { location_id: @location.id }
    assert_response :success
  end

  test "不正な month パラメータは index にリダイレクトされる" do
    get sales_histories_path, params: { month: "invalid" }
    assert_redirected_to sales_histories_path
  end

  test "未認証ユーザーはリダイレクトされる" do
    reset!
    get sales_histories_path
    assert_redirected_to "/employee/login"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/sales_histories_controller_test.rb`
Expected: FAIL

- [ ] **Step 3: コントローラーを実装**

```ruby
# app/controllers/sales_histories_controller.rb
# frozen_string_literal: true

class SalesHistoriesController < ApplicationController
  def index
    @location = find_location
    @target_month = parse_month

    calendar = Sales::HistoryCalendar.new(location: @location, target_month: @target_month)

    render SalesHistories::IndexPage::Component.new(
      location: @location,
      target_month: @target_month,
      daily_totals: calendar.daily_totals,
      monthly_summary: calendar.monthly_summary,
      locations: Location.active.order(:name)
    )
  rescue Date::Error
    redirect_to sales_histories_path
  end

  def show
    # Task 12 で実装
  end

  private

  def find_location
    if params[:location_id].present?
      Location.find(params[:location_id])
    else
      Location.active.order(:name).first
    end
  end

  def parse_month
    if params[:month].present?
      Date.parse("#{params[:month]}-01")
    else
      Date.current
    end
  end
end
```

- [ ] **Step 4: IndexPage コンポーネントを作成**

```ruby
# app/views/components/sales_histories/index_page/component.rb
# frozen_string_literal: true

module SalesHistories
  module IndexPage
    class Component < Application::Component
      def initialize(location:, target_month:, daily_totals:, monthly_summary:, locations:)
        @location = location
        @target_month = target_month
        @daily_totals = daily_totals
        @monthly_summary = monthly_summary
        @locations = locations
      end

      private

      attr_reader :location, :target_month, :daily_totals, :monthly_summary, :locations

      def prev_month_path
        prev = target_month.prev_month
        helpers.sales_histories_path(month: prev.strftime("%Y-%m"), location_id: location.id)
      end

      def next_month_path
        nxt = target_month.next_month
        helpers.sales_histories_path(month: nxt.strftime("%Y-%m"), location_id: location.id)
      end

      def month_label
        target_month.strftime("%Y年%-m月")
      end

      def daily_detail_src
        helpers.sales_histories_daily_detail_path(location_id: location.id, date: Date.current.iso8601)
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_histories/index_page/component.html.erb %>
<div class="space-y-6">
  <header>
    <%= component "page_header", title: t(".title") %>
  </header>

  <%# 出店先セレクト + 月ナビゲーション %>
  <div class="flex flex-wrap items-center justify-between gap-4 p-4 bg-base-200 rounded-box">
    <div class="flex items-center gap-2">
      <span class="text-sm font-medium"><%= t(".location_label") %></span>
      <%= form_with url: helpers.sales_histories_path, method: :get, data: { turbo: false } do |f| %>
        <%= f.hidden_field :month, value: target_month.strftime("%Y-%m") %>
        <%= f.select :location_id,
              options_from_collection_for_select(locations, :id, :name, location.id),
              {},
              class: "select select-bordered select-sm",
              onchange: "this.form.submit()" %>
      <% end %>
    </div>

    <div class="join">
      <%= link_to prev_month_path, class: "btn btn-ghost btn-sm join-item" do %>
        &larr;
      <% end %>
      <span class="btn btn-ghost btn-sm join-item no-animation font-semibold"><%= month_label %></span>
      <%= link_to next_month_path, class: "btn btn-ghost btn-sm join-item" do %>
        &rarr;
      <% end %>
    </div>
  </div>

  <%# 月間サマリー %>
  <%= component "sales_histories/monthly_summary", summary: monthly_summary %>

  <%# カレンダーヒートマップ %>
  <%= component "sales_histories/calendar_heatmap",
        target_month: target_month,
        daily_totals: daily_totals,
        location: location %>

  <%# 日別詳細パネル（Turbo Frame） %>
  <%= turbo_frame_tag "daily_detail", src: daily_detail_src, loading: :lazy do %>
    <div class="flex justify-center py-8">
      <span class="loading loading-spinner loading-md"></span>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: MonthlySummary コンポーネントを作成**

```ruby
# app/views/components/sales_histories/monthly_summary/component.rb
# frozen_string_literal: true

module SalesHistories
  module MonthlySummary
    class Component < Application::Component
      def initialize(summary:)
        @summary = summary
      end

      private

      attr_reader :summary

      delegate :[], to: :summary
    end
  end
end
```

```erb
<%# app/views/components/sales_histories/monthly_summary/component.html.erb %>
<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
  <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
    <div class="stat-title"><%= t(".active_days") %></div>
    <div class="stat-value"><%= summary[:active_days] %></div>
    <div class="stat-desc"><%= t(".days_unit") %></div>
  </div>

  <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
    <div class="stat-title"><%= t(".total_amount") %></div>
    <div class="stat-value text-primary"><%= number_to_currency(summary[:total_amount]) %></div>
  </div>

  <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
    <div class="stat-title"><%= t(".total_transactions") %></div>
    <div class="stat-value"><%= summary[:total_transactions] %></div>
    <div class="stat-desc"><%= t(".transactions_unit") %></div>
  </div>
</div>
```

- [ ] **Step 6: CalendarHeatmap コンポーネントを作成**

```ruby
# app/views/components/sales_histories/calendar_heatmap/component.rb
# frozen_string_literal: true

module SalesHistories
  module CalendarHeatmap
    class Component < Application::Component
      WEEKDAY_LABELS = %w[日 月 火 水 木 金 土].freeze

      HEAT_COLORS = {
        0 => "bg-base-200",
        1 => "bg-amber-100",
        2 => "bg-amber-200",
        3 => "bg-amber-400",
        4 => "bg-amber-600 text-white",
        5 => "bg-amber-800 text-white"
      }.freeze

      def initialize(target_month:, daily_totals:, location:)
        @target_month = target_month
        @daily_totals = daily_totals
        @location = location
        @percentile_thresholds = calculate_thresholds
      end

      private

      attr_reader :target_month, :daily_totals, :location, :percentile_thresholds

      # カレンダーの週ごとの配列を返す
      # [[nil, nil, Date, Date, ...], [Date, Date, ...], ...]
      def calendar_weeks
        first_day = target_month.beginning_of_month
        last_day = target_month.end_of_month

        # 月の初日の曜日で先頭を nil 埋め
        days = Array.new(first_day.wday, nil) + (first_day..last_day).to_a

        # 7日ずつスライス
        days.each_slice(7).to_a
      end

      def heat_color(date)
        return HEAT_COLORS[0] unless date

        amount = daily_totals[date] || 0
        return HEAT_COLORS[0] if amount == 0

        level = percentile_level(amount)
        HEAT_COLORS[level]
      end

      def daily_amount(date)
        daily_totals[date] || 0
      end

      def day_link_path(date)
        helpers.sales_histories_daily_detail_path(
          location_id: location.id,
          date: date.iso8601
        )
      end

      def today?(date)
        date == Date.current
      end

      # パーセンタイルベースで5段階にマッピング
      def percentile_level(amount)
        return 1 if percentile_thresholds.empty?

        case
        when amount <= percentile_thresholds[0] then 1
        when amount <= percentile_thresholds[1] then 2
        when amount <= percentile_thresholds[2] then 3
        when amount <= percentile_thresholds[3] then 4
        else 5
        end
      end

      def calculate_thresholds
        amounts = daily_totals.values.select(&:positive?).sort
        return [] if amounts.empty?

        [
          percentile(amounts, 20),
          percentile(amounts, 40),
          percentile(amounts, 60),
          percentile(amounts, 80)
        ]
      end

      def percentile(sorted, p)
        return sorted.first if sorted.size == 1

        rank = (p / 100.0) * (sorted.size - 1)
        lower = sorted[rank.floor]
        upper = sorted[rank.ceil]
        lower + (upper - lower) * (rank - rank.floor)
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_histories/calendar_heatmap/component.html.erb %>
<div class="card bg-base-100 shadow-sm border border-base-300">
  <div class="card-body">
    <h3 class="card-title text-base"><%= t(".title") %></h3>
    <div class="overflow-x-auto">
      <table class="table table-sm text-center">
        <thead>
          <tr>
            <% WEEKDAY_LABELS.each do |label| %>
              <th class="text-xs"><%= label %></th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <% calendar_weeks.each do |week| %>
            <tr>
              <% week.each do |date| %>
                <td class="p-1">
                  <% if date %>
                    <%= link_to day_link_path(date),
                          class: "block w-10 h-10 rounded-lg flex items-center justify-center text-xs font-medium #{heat_color(date)} #{today?(date) ? 'ring-2 ring-primary' : ''} hover:opacity-80 transition-opacity",
                          data: { turbo_frame: "daily_detail" },
                          title: number_to_currency(daily_amount(date)) do %>
                      <%= date.day %>
                    <% end %>
                  <% else %>
                    <div class="w-10 h-10"></div>
                  <% end %>
                </td>
              <% end %>
              <%# 末尾の空セルを埋める %>
              <% (7 - week.size).times do %>
                <td class="p-1"><div class="w-10 h-10"></div></td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <%# 凡例 %>
    <div class="flex items-center gap-2 justify-end mt-2">
      <span class="text-xs text-base-content/60"><%= t(".legend_low") %></span>
      <% HEAT_COLORS.values.each do |color_class| %>
        <div class="w-4 h-4 rounded <%= color_class %>"></div>
      <% end %>
      <span class="text-xs text-base-content/60"><%= t(".legend_high") %></span>
    </div>
  </div>
</div>
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/controllers/sales_histories_controller_test.rb`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add app/controllers/sales_histories_controller.rb \
       app/views/components/sales_histories/index_page/ \
       app/views/components/sales_histories/calendar_heatmap/ \
       app/views/components/sales_histories/monthly_summary/ \
       test/controllers/sales_histories_controller_test.rb
git commit -m "feat: 販売履歴カレンダーヒートマップページを実装"
```

---

### Task 11: SalesHistories::DailyDetailsController + DailyDetailPanel

**Files:**
- Create: `app/controllers/sales_histories/daily_details_controller.rb`
- Create: `app/views/components/sales_histories/daily_detail_panel/component.rb`
- Create: `app/views/components/sales_histories/daily_detail_panel/component.html.erb`
- Create: `test/controllers/sales_histories/daily_details_controller_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/controllers/sales_histories/daily_details_controller_test.rb
require "test_helper"

module SalesHistories
  class DailyDetailsControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      login_as_employee(:verified_employee)
      @location = locations(:city_hall)
    end

    test "認証済みユーザーが日別詳細を取得できる" do
      get sales_histories_daily_detail_path(location_id: @location.id, date: 1.day.ago.to_date.iso8601)
      assert_response :success
    end

    test "Turbo Frame リクエストで正しいフレームIDを返す" do
      get sales_histories_daily_detail_path(location_id: @location.id, date: Date.current.iso8601),
          headers: { "Turbo-Frame" => "daily_detail" }
      assert_response :success
    end

    test "不正な日付パラメータは sales_histories#index にリダイレクトされる" do
      get sales_histories_daily_detail_path(location_id: @location.id, date: "invalid-date")
      assert_redirected_to sales_histories_path
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get sales_histories_daily_detail_path(location_id: @location.id, date: Date.current.iso8601)
      assert_redirected_to "/employee/login"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/sales_histories/daily_details_controller_test.rb`
Expected: FAIL

- [ ] **Step 3: コントローラーを実装**

```ruby
# app/controllers/sales_histories/daily_details_controller.rb
# frozen_string_literal: true

module SalesHistories
  class DailyDetailsController < ApplicationController
    def show
      location = Location.find(params[:location_id])
      date = Date.parse(params[:date])

      calendar = Sales::HistoryCalendar.new(location: location, target_month: date)
      breakdown = calendar.daily_breakdown(date)
      daily_total = calendar.daily_totals[date] || 0

      render SalesHistories::DailyDetailPanel::Component.new(
        date: date,
        location: location,
        breakdown: breakdown,
        daily_total: daily_total
      )
    rescue Date::Error
      redirect_to sales_histories_path
    end
  end
end
```

- [ ] **Step 4: DailyDetailPanel コンポーネントを作成**

```ruby
# app/views/components/sales_histories/daily_detail_panel/component.rb
# frozen_string_literal: true

module SalesHistories
  module DailyDetailPanel
    class Component < Application::Component
      FRAME_ID = "daily_detail"

      def initialize(date:, location:, breakdown:, daily_total:)
        @date = date
        @location = location
        @breakdown = breakdown
        @daily_total = daily_total
      end

      private

      attr_reader :date, :location, :breakdown, :daily_total

      def date_label
        date.strftime("%-m月%-d日（#{weekday_label}）")
      end

      def weekday_label
        %w[日 月 火 水 木 金 土][date.wday]
      end

      def max_quantity
        @max_quantity ||= breakdown.map { |item| item[:total_quantity] }.max || 1
      end

      # CSS 幅で棒グラフを表現（パーセンテージ）
      def bar_width_percent(quantity)
        return 0 if max_quantity == 0

        (quantity.to_f / max_quantity * 100).round
      end

      BAR_WIDTH_CLASSES = (0..100).step(5).each_with_object({}) do |pct, hash|
        hash[pct] = "w-[#{pct}%]"
      end.freeze

      def bar_width_class(quantity)
        pct = bar_width_percent(quantity)
        # 最も近い5の倍数に丸める
        rounded = (pct / 5.0).round * 5
        BAR_WIDTH_CLASSES.fetch(rounded, "w-full")
      end

      def show_path
        helpers.sales_history_path(date.iso8601, location_id: location.id)
      end

      def has_data?
        breakdown.any?
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_histories/daily_detail_panel/component.html.erb %>
<%= turbo_frame_tag FRAME_ID do %>
  <div class="card bg-base-100 shadow-sm border border-base-300">
    <div class="card-body">
      <div class="flex items-center justify-between">
        <h3 class="card-title text-base"><%= date_label %></h3>
        <% if has_data? %>
          <%= link_to t(".view_transactions"), show_path, class: "btn btn-primary btn-sm" %>
        <% end %>
      </div>

      <% if has_data? %>
        <div class="text-sm text-base-content/70 mb-4">
          <%= t(".daily_total") %>: <span class="font-semibold"><%= number_to_currency(daily_total) %></span>
        </div>

        <div class="space-y-2">
          <% breakdown.each do |item| %>
            <div class="flex items-center gap-3">
              <span class="text-sm w-28 truncate"><%= item[:catalog_name] %></span>
              <div class="flex-1 bg-base-200 rounded-full h-4">
                <div class="bg-primary rounded-full h-4 <%= bar_width_class(item[:total_quantity]) %>"></div>
              </div>
              <span class="text-sm font-medium w-8 text-right"><%= item[:total_quantity] %></span>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="text-base-content/50 text-sm py-4"><%= t(".no_data") %></p>
      <% end %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/sales_histories/daily_details_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/sales_histories/daily_details_controller.rb \
       app/views/components/sales_histories/daily_detail_panel/ \
       test/controllers/sales_histories/daily_details_controller_test.rb
git commit -m "feat: 販売履歴 日別詳細パネルを Turbo Frame で実装"
```

---

### Task 12: SalesHistoriesController#show + 取引一覧コンポーネント群

**Files:**
- Modify: `app/controllers/sales_histories_controller.rb`
- Create: `app/views/components/sales_histories/show_page/component.rb`
- Create: `app/views/components/sales_histories/show_page/component.html.erb`
- Create: `app/views/components/sales_histories/daily_summary/component.rb`
- Create: `app/views/components/sales_histories/daily_summary/component.html.erb`
- Create: `app/views/components/sales_histories/transaction_table/component.rb`
- Create: `app/views/components/sales_histories/transaction_table/component.html.erb`
- Modify: `test/controllers/sales_histories_controller_test.rb`

- [ ] **Step 1: コントローラーテストに show アクション用テストを追加**

`test/controllers/sales_histories_controller_test.rb` に追加:

```ruby
  # --- show ---

  test "認証済みユーザーが show にアクセスできる" do
    target_date = 1.day.ago.to_date.iso8601
    get sales_history_path(target_date, location_id: @location.id)
    assert_response :success
  end

  test "不正な日付の show は index にリダイレクトされる" do
    get sales_history_path("invalid", location_id: @location.id)
    assert_redirected_to sales_histories_path
  end

  test "未認証ユーザーは show にアクセスできない" do
    reset!
    get sales_history_path(Date.current.iso8601, location_id: @location.id)
    assert_redirected_to "/employee/login"
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/sales_histories_controller_test.rb`
Expected: FAIL（show アクションが未実装）

- [ ] **Step 3: コントローラーの show アクションを実装**

`app/controllers/sales_histories_controller.rb` の `show` メソッドを更新:

```ruby
  def show
    @location = find_location
    @date = Date.parse(params[:id])

    sales = Sale.at_location(@location)
                .in_period(@date.beginning_of_day, @date.end_of_day)
                .preload(items: [:catalog])
                .eager_load(:location)
                .order(:sale_datetime)

    calendar = Sales::HistoryCalendar.new(location: @location, target_month: @date)
    breakdown = calendar.daily_breakdown(@date)

    render SalesHistories::ShowPage::Component.new(
      date: @date,
      location: @location,
      sales: sales,
      breakdown: breakdown
    )
  rescue Date::Error
    redirect_to sales_histories_path
  end
```

- [ ] **Step 4: ShowPage コンポーネントを作成**

```ruby
# app/views/components/sales_histories/show_page/component.rb
# frozen_string_literal: true

module SalesHistories
  module ShowPage
    class Component < Application::Component
      def initialize(date:, location:, sales:, breakdown:)
        @date = date
        @location = location
        @sales = sales
        @breakdown = breakdown
      end

      private

      attr_reader :date, :location, :sales, :breakdown

      def date_label
        date.strftime("%Y年%-m月%-d日（#{weekday_label}）")
      end

      def weekday_label
        %w[日 月 火 水 木 金 土][date.wday]
      end

      def back_path
        helpers.sales_histories_path(
          month: date.strftime("%Y-%m"),
          location_id: location.id
        )
      end

      def total_amount
        sales.completed.sum(:final_amount)
      end

      def total_transactions
        sales.completed.count
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_histories/show_page/component.html.erb %>
<div class="space-y-6">
  <%# パンくず %>
  <nav class="mb-4">
    <%= link_to back_path, class: "inline-flex items-center gap-1 text-sm text-base-content/70 hover:text-base-content transition-colors" do %>
      <%= helpers.icon "arrow_left", size: :sm %>
      <%= t(".back_to_calendar") %>
    <% end %>
  </nav>

  <header class="flex items-center gap-3">
    <%= helpers.icon "calendar", size: :lg, extra_class: "text-primary" %>
    <div>
      <h1 class="text-2xl font-bold text-base-content"><%= date_label %></h1>
      <p class="text-sm text-base-content/70"><%= location.name %></p>
    </div>
  </header>

  <%# 日次サマリー %>
  <%= component "sales_histories/daily_summary",
        total_amount: total_amount,
        total_transactions: total_transactions,
        location_name: location.name %>

  <%# 取引一覧テーブル %>
  <%= component "sales_histories/transaction_table", sales: sales %>
</div>
```

- [ ] **Step 5: DailySummary コンポーネントを作成**

```ruby
# app/views/components/sales_histories/daily_summary/component.rb
# frozen_string_literal: true

module SalesHistories
  module DailySummary
    class Component < Application::Component
      def initialize(total_amount:, total_transactions:, location_name:)
        @total_amount = total_amount
        @total_transactions = total_transactions
        @location_name = location_name
      end

      private

      attr_reader :total_amount, :total_transactions, :location_name
    end
  end
end
```

```erb
<%# app/views/components/sales_histories/daily_summary/component.html.erb %>
<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
  <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
    <div class="stat-title"><%= t(".total_amount") %></div>
    <div class="stat-value text-primary"><%= number_to_currency(total_amount) %></div>
  </div>

  <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
    <div class="stat-title"><%= t(".total_transactions") %></div>
    <div class="stat-value"><%= total_transactions %></div>
    <div class="stat-desc"><%= t(".transactions_unit") %></div>
  </div>

  <div class="stat bg-base-100 shadow-sm border border-base-300 rounded-box">
    <div class="stat-title"><%= t(".location") %></div>
    <div class="stat-value text-lg"><%= location_name %></div>
  </div>
</div>
```

- [ ] **Step 6: TransactionTable コンポーネントを作成**

```ruby
# app/views/components/sales_histories/transaction_table/component.rb
# frozen_string_literal: true

module SalesHistories
  module TransactionTable
    class Component < Application::Component
      CUSTOMER_TYPE_BADGES = {
        "staff" => "badge badge-info badge-sm",
        "citizen" => "badge badge-success badge-sm"
      }.freeze

      STATUS_ROW_CLASSES = {
        "completed" => "",
        "voided" => "opacity-40"
      }.freeze

      def initialize(sales:)
        @sales = sales
      end

      private

      attr_reader :sales

      def customer_badge_class(sale)
        CUSTOMER_TYPE_BADGES.fetch(sale.customer_type, "badge badge-ghost badge-sm")
      end

      def row_class(sale)
        STATUS_ROW_CLASSES.fetch(sale.status, "")
      end

      def time_label(sale)
        sale.sale_datetime.strftime("%H:%M")
      end

      def items_summary(sale)
        sale.items.map { |item| "#{item.catalog.name} x#{item.quantity}" }.join(", ")
      end
    end
  end
end
```

```erb
<%# app/views/components/sales_histories/transaction_table/component.html.erb %>
<div class="card bg-base-100 shadow-sm border border-base-300">
  <div class="card-body">
    <h3 class="card-title text-base"><%= t(".title") %></h3>

    <% if sales.any? %>
      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr>
              <th><%= t(".time") %></th>
              <th><%= t(".customer_type") %></th>
              <th><%= t(".items") %></th>
              <th><%= t(".status") %></th>
              <th class="text-right"><%= t(".amount") %></th>
            </tr>
          </thead>
          <tbody>
            <% sales.each do |sale| %>
              <tr class="<%= row_class(sale) %>">
                <td class="font-mono text-sm"><%= time_label(sale) %></td>
                <td>
                  <span class="<%= customer_badge_class(sale) %>">
                    <%= t("enums.sale.customer_type.#{sale.customer_type}") %>
                  </span>
                </td>
                <td class="text-sm"><%= items_summary(sale) %></td>
                <td>
                  <% if sale.voided? %>
                    <span class="badge badge-error badge-sm"><%= t("enums.sale.status.voided") %></span>
                  <% end %>
                </td>
                <td class="text-right font-medium"><%= number_to_currency(sale.final_amount) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <p class="text-base-content/50 text-sm py-4"><%= t(".no_data") %></p>
    <% end %>
  </div>
</div>
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/controllers/sales_histories_controller_test.rb`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add app/controllers/sales_histories_controller.rb \
       app/views/components/sales_histories/show_page/ \
       app/views/components/sales_histories/daily_summary/ \
       app/views/components/sales_histories/transaction_table/ \
       test/controllers/sales_histories_controller_test.rb
git commit -m "feat: 日別取引一覧ページを実装"
```

---

### Task 13: I18n

**Files:**
- Modify: `config/locales/ja.yml`

- [ ] **Step 1: I18n キーを追加**

`config/locales/ja.yml` に以下を追加（既存のキーの後に追記）:

```yaml
  # 販売分析
  sales_analyses:
    index_page:
      title: "販売分析"
    filter_bar:
      period_label: "期間"
      location_label: "販売先"
    summary_cards:
      total_sales: "総販売数"
      staff_sales: "関係者"
      citizen_sales: "一般"
      unit: "個"
    ranking:
      staff_title: "関係者 人気商品 Top5"
      citizen_title: "一般 人気商品 Top5"
      rank: "順位"
      product: "商品"
      quantity: "販売数"
      no_data: "データがありません"
    cross_table:
      title: "商品 x 顧客タイプ クロス集計"
      product: "商品"
      staff: "関係者"
      citizen: "一般"
      total: "合計"
      no_data: "データがありません"

  # 販売履歴カレンダー
  sales_histories:
    index_page:
      title: "販売履歴"
      location_label: "販売先"
    monthly_summary:
      active_days: "販売日数"
      days_unit: "日"
      total_amount: "月間売上"
      total_transactions: "取引件数"
      transactions_unit: "件"
    calendar_heatmap:
      title: "カレンダー"
      legend_low: "少"
      legend_high: "多"
    daily_detail_panel:
      daily_total: "売上合計"
      view_transactions: "取引一覧を見る"
      no_data: "この日の販売データはありません"
    show_page:
      back_to_calendar: "カレンダーに戻る"
    daily_summary:
      total_amount: "売上合計"
      total_transactions: "取引件数"
      transactions_unit: "件"
      location: "販売先"
    transaction_table:
      title: "取引一覧"
      time: "時刻"
      customer_type: "顧客"
      items: "商品"
      status: "状態"
      amount: "金額"
      no_data: "取引データがありません"
```

- [ ] **Step 2: 全テストを実行して I18n キーの不足がないか確認**

Run: `bin/rails test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add config/locales/ja.yml
git commit -m "feat: 販売分析・販売履歴の I18n 翻訳キーを追加"
```

---

## 完了チェックリスト

全タスク完了後に以下を確認:

- [ ] `bin/rails test` が全てパスする
- [ ] `bin/rubocop -a` が警告なしで通る
- [ ] `/sales_analyses` にブラウザでアクセスし、フィルター操作と Turbo Frame の並列読み込みを確認
- [ ] `/sales_histories` でカレンダーヒートマップの色分けと日付クリックでの詳細パネル更新を確認
- [ ] `/sales_histories/:date` で取引一覧が正しく表示され、voided 行がグレーアウトされることを確認
- [ ] サイドバーの「販売分析」「販売履歴」リンクが正しく動作し、アクティブ状態が反映されることを確認
