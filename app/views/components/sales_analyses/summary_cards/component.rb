# frozen_string_literal: true

module SalesAnalyses
  module SummaryCards
    class Component < Application::Component
      def initialize(data:)
        @data = data
      end

      private

      attr_reader :data

      def total_quantity
        data[:staff][:quantity] + data[:citizen][:quantity]
      end

      def total_amount
        data[:staff][:amount] + data[:citizen][:amount]
      end

      def staff_ratio
        return 0 if total_quantity.zero?
        (data[:staff][:quantity] * 100.0 / total_quantity).round
      end

      def citizen_ratio
        return 0 if total_quantity.zero?
        (data[:citizen][:quantity] * 100.0 / total_quantity).round
      end
    end
  end
end
