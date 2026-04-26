# frozen_string_literal: true

module SalesHistories
  module DailyDetailPanel
    class Component < Application::Component
      def initialize(date:, location:, breakdown:, daily_total:)
        @date = date
        @location = location
        @breakdown = breakdown
        @daily_total = daily_total
      end

      private

      attr_reader :date, :location, :breakdown, :daily_total

      def total_quantity
        breakdown.sum { |row| row[:total_quantity] }
      end

      def show_path
        helpers.sales_history_path(date.to_s, location_id: location.id)
      end

      def max_quantity
        @max_quantity ||= breakdown.map { |r| r[:total_quantity] }.max || 1
      end

      def bar_width(qty)
        "#{(qty * 100.0 / max_quantity).round}%"
      end
    end
  end
end
