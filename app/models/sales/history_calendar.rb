# frozen_string_literal: true

module Sales
  class HistoryCalendar
    include CustomerTypePivot
    def initialize(location:, month:)
      @location = location
      @month = month
    end

    # 対象月の日別の弁当販売数
    #
    # 販売のあった日は弁当が 1 個も売れていなくてもキーに残す。サラダしか売れなかった
    # 日を落とすと、ヒートマップがその日を休みとして描く（ADR-0006）
    #
    # @return [Hash{Date => Integer}]
    def daily_quantities
      @daily_quantities ||= begin
        quantities = bento_quantities_by_date
        sales_dates.index_with { |date| quantities[date] || 0 }
      end
    end

    # 月間サマリー
    # @return [Hash] { business_days:, total_quantity:, daily_average:, best_day: { date:, quantity: } }
    def monthly_summary
      quantities = daily_quantities
      total = quantities.values.sum
      days = quantities.size
      best = quantities.max_by { |_, quantity| quantity }

      {
        business_days: days,
        total_quantity: total,
        daily_average: days > 0 ? total / days : 0,
        best_day: best ? { date: best[0], quantity: best[1] } : nil
      }
    end

    # 指定日の弁当別販売内訳（顧客タイプ別）
    # @return [Array<Hash>] [{ catalog_name:, staff_quantity:, citizen_quantity:, total_quantity: }, ...]
    def daily_breakdown(date)
      rows = completed_sales(*day_range(date))
        .joining_bento_items
        .group("catalogs.name", :customer_type)
        .pluck(
          Arel.sql("catalogs.name"),
          :customer_type,
          Arel.sql("SUM(sale_items.quantity)")
        )

      pivot_by_customer_type(rows)
    end

    # 指定日に売れた弁当の個数
    #
    # @return [Integer]
    def bento_quantity(date)
      completed_sales(*day_range(date))
        .joining_bento_items
        .sum("sale_items.quantity")
    end

    # 指定日の取引件数
    #
    # 取引の件数であって商品の数ではないため、弁当で絞らない。サラダしか売れなかった日も
    # 取引は立つ（ADR-0006）
    #
    # @return [Integer]
    def transaction_count(date)
      completed_sales(*day_range(date)).count
    end

    private

    attr_reader :location, :month

    def completed_sales(from, to)
      Sale.completed
          .at_location(location)
          .in_period(from, to)
    end

    # 対象月のうち販売があった日。弁当が売れたかどうかは問わない
    def sales_dates
      completed_sales(month_range.first, month_range.last)
        .distinct
        .pluck(Sale.jst_date_expression)
        .map { |date_str| Date.parse(date_str) }
        .sort
    end

    def bento_quantities_by_date
      completed_sales(month_range.first, month_range.last)
        .joining_bento_items
        .group(Sale.jst_date_expression)
        .sum("sale_items.quantity")
        .transform_keys { |date_str| Date.parse(date_str) }
    end

    def day_range(date)
      [ date.in_time_zone.beginning_of_day, date.in_time_zone.end_of_day ]
    end

    def month_range
      month.beginning_of_month.beginning_of_day..month.end_of_month.end_of_day
    end
  end
end
