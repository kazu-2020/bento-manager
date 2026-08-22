# frozen_string_literal: true

module SalesHistories
  module MonthlySummary
    class Component < Application::Component
      NO_DATA = "-"

      def initialize(summary:)
        @summary = summary
      end

      private

      attr_reader :summary

      def best_day
        summary[:best_day]
      end

      def total_quantity
        summary[:total_quantity]
      end

      # 1 個未満まで出すが、割り切れる月に 20.0 個と出しても読み手の役に立たない
      def daily_average
        helpers.number_with_precision(summary[:daily_average], precision: 1, strip_insignificant_zeros: true)
      end

      def best_day_label
        return nil unless best_day

        best_day[:date].strftime("%-m/%-d")
      end
    end
  end
end
