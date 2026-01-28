# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module InventorySummary
      class Component < Application::Component
        def initialize(inventories:)
          @inventories = inventories
        end

        attr_reader :inventories

        def total_available_stock
          inventories.sum(&:available_stock)
        end
      end
    end
  end
end
