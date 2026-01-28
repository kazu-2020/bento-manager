# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module IndexPage
      class Component < Application::Component
        def initialize(location:, inventories:, additional_orders:)
          @location = location
          @inventories = inventories
          @additional_orders = additional_orders
        end

        attr_reader :location, :inventories, :additional_orders

        def new_order_url
          helpers.new_pos_location_additional_order_path(location)
        end

        def has_inventories?
          inventories.any?
        end

        def render_inventory_summary
          render Pos::AdditionalOrders::InventorySummary::Component.new(inventories: inventories)
        end

        def render_history_list
          render Pos::AdditionalOrders::HistoryList::Component.new(additional_orders: additional_orders)
        end
      end
    end
  end
end
