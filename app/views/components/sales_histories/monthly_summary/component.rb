# frozen_string_literal: true

module SalesHistories
  module MonthlySummary
    class Component < Application::Component
      def initialize(summary:)
        @summary = summary
      end

      private

      attr_reader :summary

      def best_day
        summary[:best_day]
      end

      def best_day_amount
        return "-" unless best_day

        "¥#{number_with_delimiter(best_day[:amount])}"
      end

      def best_day_label
        best_day[:date].strftime("%-m/%-d")
      end
    end
  end
end
