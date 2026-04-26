# frozen_string_literal: true

module SalesAnalyses
  module CrossTable
    class Component < Application::Component
      def initialize(data:)
        @data = data
      end

      private

      attr_reader :data

      def grand_total
        @grand_total ||= data.sum { |row| row[:total_quantity] }
      end

      def composition_ratio(row)
        return 0 if grand_total.zero?
        (row[:total_quantity] * 100.0 / grand_total).round(1)
      end

      def staff_ratio(row)
        return 0 if row[:total_quantity].zero?
        (row[:staff_quantity] * 100.0 / row[:total_quantity]).round
      end

      def max_total
        @max_total ||= data.map { |r| r[:total_quantity] }.max || 1
      end

      def bar_total_width(row)
        "#{(row[:total_quantity] * 100.0 / max_total).round}%"
      end

      def staff_bar_ratio(row)
        return "0%" if row[:total_quantity].zero?
        "#{(row[:staff_quantity] * 100.0 / row[:total_quantity]).round}%"
      end
    end
  end
end
