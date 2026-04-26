# frozen_string_literal: true

module Sales
  class HistoryCalendar
    include CustomerTypePivot
    def initialize(location:, month:)
      @location = location
      @month = month
    end

    # 対象月の日別売上合計
    # @return [Hash{Date => Integer}]
    def daily_totals
      @daily_totals ||= Sale.completed
        .at_location(location)
        .in_period(month_range.first, month_range.last)
        .group(jst_date_expression)
        .sum(:final_amount)
        .transform_keys { |date_str| Date.parse(date_str) }
    end

    # 月間サマリー
    # @return [Hash] { business_days:, total_amount:, daily_average:, best_day: { date:, amount: } }
    def monthly_summary
      totals = daily_totals
      total = totals.values.sum
      days = totals.size
      best = totals.max_by { |_, v| v }

      {
        business_days: days,
        total_amount: total,
        daily_average: days > 0 ? total / days : 0,
        best_day: best ? { date: best[0], amount: best[1] } : nil
      }
    end

    # 指定日の商品別販売内訳（顧客タイプ別）
    # @return [Array<Hash>] [{ catalog_name:, staff_quantity:, citizen_quantity:, total_quantity: }, ...]
    def daily_breakdown(date)
      day_start = date.in_time_zone.beginning_of_day
      day_end = date.in_time_zone.end_of_day

      rows = Sale.completed
        .at_location(location)
        .in_period(day_start, day_end)
        .joins(items: :catalog)
        .group("catalogs.name", :customer_type)
        .pluck(
          Arel.sql("catalogs.name"),
          :customer_type,
          Arel.sql("SUM(sale_items.quantity)")
        )

      pivot_by_customer_type(rows)
    end

    private

    attr_reader :location, :month

    def month_range
      month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day
    end

    # SQLite の DATE() は UTC ベース。JST オフセットを適用
    def jst_date_expression
      offset = Time.zone.now.formatted_offset
      Arel.sql(Sale.sanitize_sql_array([ "DATE(sale_datetime, ?)", offset ]))
    end
  end
end
