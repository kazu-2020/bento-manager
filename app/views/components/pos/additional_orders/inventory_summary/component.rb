# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module InventorySummary
      class Component < Application::Component
        def initialize(inventories:)
          @inventories = inventories
        end

        attr_reader :inventories

        def has_items?
          inventories.any?
        end

        def total_available_stock
          inventories.sum(&:available_stock)
        end

        def items
          inventories
        end
      end
    end
  end
end
