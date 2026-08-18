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

      def formatted_total_amount
        helpers.number_to_currency(summary[:total_amount])
      end

      def formatted_daily_average
        helpers.number_to_currency(summary[:daily_average])
      end

      def formatted_best_day_amount
        helpers.number_to_currency(best_day[:amount]) if best_day
      end

      def best_day_label
        return nil unless best_day

        best_day[:date].strftime("%-m/%-d")
      end
    end
  end
end
