# frozen_string_literal: true

module Locations
  module SalesChart
    class Component < Application::Component
      PERIOD = 1.month

      def initialize(location:)
        @location = location
      end

      def chart_data
        @chart_data ||= build_chart_data
      end

      private

      def build_chart_data
        raw = @location.daily_sales_quantity(period: PERIOD)
        date_range = (PERIOD.ago.to_date..Date.current)

        [
          { name: t(".staff_label"),   data: date_range.map { |d| [ d, raw[[ d.to_s, "staff" ]] || 0 ] }.to_h },
          { name: t(".citizen_label"), data: date_range.map { |d| [ d, raw[[ d.to_s, "citizen" ]] || 0 ] }.to_h }
        ]
      end
    end
  end
end
