# frozen_string_literal: true

module Locations
  module SalesChart
    class Component < Application::Component
      PERIOD = 1.month
      COLORS = [ "#e67e22", "#16a34a" ].freeze

      def initialize(location:)
        @location = location
      end

      def chart_data
        @chart_data ||= build_chart_data
      end

      def chart_colors
        COLORS
      end

      def chart_options
        {
          scales: {
            x: { ticks: { maxRotation: 0, autoSkipPadding: 12 }, grid: { display: false } },
            y: { beginAtZero: true, ticks: { stepSize: 1, precision: 0 }, grid: { color: "rgba(0, 0, 0, 0.06)" } }
          },
          plugins: {
            legend: { labels: { font: { size: 13 }, usePointStyle: true, pointStyle: "circle", padding: 20 } }
          }
        }
      end

      def dataset_options
        { borderWidth: 3, pointRadius: 4, pointHoverRadius: 6, pointBorderWidth: 2, tension: 0.3 }
      end

      private

      def build_chart_data
        raw = @location.daily_sales_quantity(period: PERIOD)
        date_range = (PERIOD.ago.to_date..Date.current)

        [
          { name: t(".staff_label"),   data: series_for(date_range, raw, "staff") },
          { name: t(".citizen_label"), data: series_for(date_range, raw, "citizen") }
        ]
      end

      def series_for(date_range, raw, customer_type)
        date_range.map { |d| [ d.strftime("%-m/%-d"), raw[[ d.to_s, customer_type ]] || 0 ] }.to_h
      end
    end
  end
end
