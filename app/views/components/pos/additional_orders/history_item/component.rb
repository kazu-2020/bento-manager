# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module HistoryItem
      class Component < Application::Component
        def initialize(order:)
          @order = order
        end

        attr_reader :order

        def order_time
          I18n.l(order.order_at, format: :short)
        end

        def catalog_name
          order.catalog.name
        end

        def quantity
          order.quantity
        end

        def employee_name
          order.employee&.username || t(".unknown_employee")
        end
      end
    end
  end
end
