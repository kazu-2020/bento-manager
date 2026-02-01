# frozen_string_literal: true

module Pos
  module Dock
    class Component < Application::Component
      def initialize(location:, current_path:)
        @location = location
        @current_path = current_path
      end

      attr_reader :location, :current_path

      def items
        [
          {
            icon: "shopping_cart",
            label: t(".sales"),
            path: helpers.new_pos_location_sale_path(location),
            active_pattern: %r{/sales/new}
          },
          {
            icon: "clipboard_list",
            label: t(".history"),
            path: helpers.pos_location_sales_history_index_path(location),
            active_pattern: %r{/sales_history|/refunds}
          },
          {
            icon: "truck",
            label: t(".orders"),
            path: helpers.pos_location_additional_orders_path(location),
            active_pattern: %r{/additional_orders}
          }
        ]
      end

      def active?(item)
        current_path.match?(item[:active_pattern])
      end
    end
  end
end
