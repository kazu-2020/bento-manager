# frozen_string_literal: true

module SalesHistories
  module CalendarHeatmap
    class Component < Application::Component
      HEAT_COLORS = {
        0 => "bg-base-200 text-base-content/30",
        1 => "bg-amber-100 text-base-content",
        2 => "bg-amber-200 text-base-content",
        3 => "bg-amber-400 text-white",
        4 => "bg-amber-600 text-white",
        5 => "bg-amber-800 text-white"
      }.freeze

      WEEKDAY_NAMES = %w[日 月 火 水 木 金 土].freeze

      def initialize(month:, daily_totals:, location:)
        @month = month
        @daily_totals = daily_totals
        @location = location
      end

      private

      attr_reader :month, :daily_totals, :location

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

      def heat_level(date)
        amount = daily_totals[date]
        return 0 unless amount

        thresholds = compute_thresholds
        case amount
        when ...thresholds[0] then 1
        when ...thresholds[1] then 2
        when ...thresholds[2] then 3
        when ...thresholds[3] then 4
        else 5
        end
      end

      def heat_class(date)
        HEAT_COLORS[heat_level(date)]
      end

      def amount_display(date)
        amount = daily_totals[date]
        return nil unless amount

        if amount >= 10_000
          "¥#{(amount / 1000.0).round(1)}k"
        else
          "¥#{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse}"
        end
      end

      def daily_detail_path(date)
        helpers.sales_histories_daily_detail_path(
          location_id: location.id,
          date: date.to_s
        )
      end

      def compute_thresholds
        @compute_thresholds ||= begin
          values = daily_totals.values.sort
          return [ 0, 0, 0, 0 ] if values.empty?
          [
            percentile(values, 20),
            percentile(values, 40),
            percentile(values, 60),
            percentile(values, 80)
          ]
        end
      end

      def percentile(sorted_values, pct)
        return 0 if sorted_values.empty?
        k = (pct / 100.0 * (sorted_values.length - 1)).round
        sorted_values[k]
      end
    end
  end
end
