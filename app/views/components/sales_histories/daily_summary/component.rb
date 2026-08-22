# frozen_string_literal: true

module SalesHistories
  module DailySummary
    class Component < Application::Component
      def initialize(total_quantity:, total_transactions:, location:)
        @total_quantity = total_quantity
        @total_transactions = total_transactions
        @location = location
      end

      private

      attr_reader :total_quantity, :total_transactions, :location
    end
  end
end
