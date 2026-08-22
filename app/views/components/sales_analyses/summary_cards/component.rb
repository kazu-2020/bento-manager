# frozen_string_literal: true

module SalesAnalyses
  module SummaryCards
    class Component < Application::Component
      # 顧客タイプごとの弁当の販売個数。売上分析が数えるのは個数だけで、金額は扱わない
      def initialize(quantities:)
        @quantities = quantities
      end

      private

      attr_reader :quantities

      def total_quantity
        quantities[:staff] + quantities[:citizen]
      end

      def ratio_of(quantity)
        return 0 if total_quantity.zero?
        (quantity * 100.0 / total_quantity).round
      end
    end
  end
end
