# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module HistoryList
      class Component < Application::Component
        def initialize(additional_orders:)
          @additional_orders = additional_orders
        end

        attr_reader :additional_orders

        def has_orders?
          additional_orders.any?
        end

        def total_quantity
          additional_orders.sum(&:quantity)
        end

        def render_history_item(order)
          render Pos::AdditionalOrders::HistoryItem::Component.new(order: order)
        end
      end
    end
  end
end
