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

      WEEKDAY_NAMES = %w[日 月 火 水 木 金 土].freeze

      def initialize(month:, daily_quantities:, location:)
        @month = month
        @daily_quantities = daily_quantities
        @location = location
      end

      private

      attr_reader :month, :daily_quantities, :location

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

      # 弁当が 1 個も売れなかった日は色をつけない。サラダしか売れていない日であり、
      # 売れた日と同じ濃さで塗ると弁当の売れ方を読み違える
      def heat_level(date)
        quantity = daily_quantities[date]
        return 0 if quantity.nil? || quantity.zero?

        compute_thresholds.count { |threshold| quantity >= threshold } + 1
      end

      def heat_class(date)
        HEAT_COLORS[heat_level(date)]
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

      # 濃淡の境目は弁当が売れた日だけから取る。0 個の日を混ぜると、サラダしか
      # 売れなかった日が増えるほど境目が下がり、少し売れた日まで濃く塗られる
      def compute_thresholds
        @compute_thresholds ||= begin
          values = daily_quantities.values.reject(&:zero?).sort
          values.empty? ? [] : [ 20, 40, 60, 80 ].map { |pct| percentile(values, pct) }
        end
      end

      def percentile(sorted_values, pct)
        k = (pct / 100.0 * (sorted_values.length - 1)).round
        sorted_values[k]
      end
    end
  end
end
