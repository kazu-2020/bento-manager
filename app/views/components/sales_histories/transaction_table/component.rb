# frozen_string_literal: true

module SalesHistories
  module TransactionTable
    class Component < Application::Component
      CUSTOMER_BADGE_CLASSES = {
        "staff" => "badge badge-sm bg-staff text-white",
        "citizen" => "badge badge-sm bg-citizen text-white"
      }.freeze

      CUSTOMER_LABELS = {
        "staff" => "関係者",
        "citizen" => "一般"
      }.freeze

      def initialize(sales:)
        @sales = sales
      end

      private

      attr_reader :sales

      def badge_class(sale)
        sale.voided? ? "badge badge-sm badge-ghost" : CUSTOMER_BADGE_CLASSES[sale.customer_type]
      end

      def badge_label(sale)
        CUSTOMER_LABELS[sale.customer_type]
      end

      def item_names(sale)
        sale.items.map { |item| item.catalog.name }.join(", ")
      end

      def total_quantity(sale)
        sale.items.sum(&:quantity)
      end

      def row_class(sale)
        sale.voided? ? "opacity-40" : ""
      end
    end
  end
end
