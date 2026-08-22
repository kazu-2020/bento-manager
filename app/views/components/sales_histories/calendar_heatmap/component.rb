# frozen_string_literal: true

module SalesHistories
  module CalendarHeatmap
    class Component < Application::Component
      HEAT_COLORS = {
        0 => "bg-base-200 text-base-content/30",
        1 => "bg-primary/20 text-base-content",
        2 => "bg-primary/40 text-base-content",
        3 => "bg-primary/60 text-white",
        4 => "bg-primary/80 text-white",
        5 => "bg-primary text-white"
      }.freeze

      # 濃淡の境目。月に依らない固定値なので、同じ濃さが月をまたいでも同じ売れ方を指す。
      # 等間隔にせず上へ寄せているのは、適正残数 2〜3 個の商いでは目標どおりに終えた日が
      # 90% 前後に集まり、20% 刻みだと大半が最濃に潰れるため（ADR-0008）
      SELL_THROUGH_THRESHOLDS = [ 0.5, 0.7, 0.85, 0.95 ].freeze

      # 残数 0 の印。凡例とマスの両方が同じ丸を出す
      NO_REMAINING_STOCK_MARKER = "w-2 h-2 rounded-full bg-warning"

      WEEKDAY_NAMES = %w[日 月 火 水 木 金 土].freeze

      def initialize(month:, daily_quantities:, daily_sell_through:, location:)
        @month = month
        @daily_quantities = daily_quantities
        @daily_sell_through = daily_sell_through
        @location = location
      end

      private

      attr_reader :month, :daily_quantities, :daily_sell_through, :location

      def weeks
        first_day = month.beginning_of_month
        last_day = month.end_of_month
        start_date = first_day - first_day.wday.days
        end_date = last_day + (6 - last_day.wday).days
        (start_date..end_date).each_slice(7).to_a
      end

      def in_month?(date)
        date.month == month.month && date.year == month.year
      end

      # 弁当を積まなかった日（消化率が定まらない日）と、積んだが 1 個も売れなかった日は
      # どちらも色をつけない。売れた日と同じ濃さで塗ると弁当の売れ方を読み違える
      # （ADR-0006 / ADR-0008）
      def heat_level(date)
        rate = daily_sell_through[date]&.rate
        return 0 if rate.nil? || rate.zero?

        SELL_THROUGH_THRESHOLDS.count { |threshold| rate >= threshold } + 1
      end

      def heat_class(date)
        HEAT_COLORS[heat_level(date)]
      end

      # 濃淡が答えているのは「どれだけよく売れたか」であって「売り切れたか」ではない。
      # 買いに来た客を逃した可能性のある日は、最濃のマスの中でも見分けられる必要がある
      def no_remaining_stock?(date)
        daily_sell_through[date]&.no_remaining_stock? || false
      end

      def quantity_display(date)
        quantity = daily_quantities[date]
        return nil unless quantity

        "#{quantity}#{t('.quantity_unit')}"
      end

      def daily_detail_path(date)
        helpers.sales_histories_daily_detail_path(
          location_id: location.id,
          date: date.to_s
        )
      end
    end
  end
end
