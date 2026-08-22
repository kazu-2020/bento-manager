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

    # 対象月の日別の消化率
    #
    # 弁当を 1 個も積まなかった日はキーごと落とす。分母が 0 で率が定まらないため、
    # 0% として薄く塗るのも 100% として売り切り扱いするのも、どちらも嘘になる
    #
    # @return [Hash{Date => Float}] 0.0〜1.0
    def daily_sell_through_rates
      @daily_sell_through_rates ||= loaded_quantities.to_h do |date, loaded|
        [ date, daily_quantities[date] / loaded.to_f ]
      end
    end

    # 月間サマリー
    #
    # 1 日平均の分母は販売のあった日であり、弁当が売れなかった日も数える。積込数を
    # 決めるために見る数字なので、店を開けたのに売れなかった日を落とすと平均が
    # 上振れし、積みすぎる方向に読ませる。同じ 0 個の日を最高日が外すのは、
    # あちらが「どの日がよく売れたか」を答えるためであり、別の判断である（ADR-0006）
    #
    # 整数除算にしないのは、単位が円から個に変わって切り捨ての意味が変わったため。
    # 1 円未満は見えないが、1 個未満は 1 日 20〜30 個の商いで数 % の下振れになる
    #
    # @return [Hash] { business_days:, total_quantity:, daily_average:, best_day: { date:, quantity: } }
    def monthly_summary
      quantities = daily_quantities
      total = quantities.values.sum
      days = quantities.size

      {
        business_days: days,
        total_quantity: total,
        daily_average: days > 0 ? (total.to_f / days).round(1) : 0.0,
        best_day: best_day(quantities)
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

    # 弁当が売れた日だけを比べる。0 個の日を混ぜると、ヒートマップが色をつけない日を
    # 隣のサマリが最高日として名指しすることになる
    def best_day(quantities)
      best = quantities.reject { |_, quantity| quantity.zero? }.max_by { |_, quantity| quantity }
      return nil unless best

      { date: best[0], quantity: best[1] }
    end

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

    # 販売のあった日ごとの、その日に積んだ弁当の総数。1 個も積まなかった日は落とす
    #
    # 積んだ総数は保存していない。当日在庫は登録・在庫訂正・追加発注でしか増えず、
    # 確定した販売でしか減らないため、残数に確定した販売数を戻せば積んだ総数になる。
    # 在庫訂正は販売開始前にしか行えないので、訂正で宣言された個数がそのまま
    # 残数と販売数に分かれ、追加発注はその場で当日在庫に加わる。取消された販売は
    # 在庫が戻るので残数の側に含まれ、分子からも分母からも二重に数えられない
    def loaded_quantities
      @loaded_quantities ||= begin
        remaining = bento_stocks_by_date

        daily_quantities.filter_map do |date, sold|
          loaded = remaining.fetch(date, 0) + sold
          [ date, loaded ] unless loaded.zero?
        end.to_h
      end
    end

    # 対象月の日別の弁当の残数。サイドメニューの在庫行は数えない（ADR-0006）
    def bento_stocks_by_date
      DailyInventory
        .where(location: location, inventory_date: month.beginning_of_month..month.end_of_month)
        .bento
        .group(:inventory_date)
        .sum(:stock)
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
