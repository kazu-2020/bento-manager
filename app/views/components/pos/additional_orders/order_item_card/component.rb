# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module OrderItemCard
      class Component < Application::Component
        def initialize(item:, hidden: false)
          @item = item
          @hidden = hidden
        end

        attr_reader :item

        delegate :catalog_id, :catalog_name, :available_stock, :quantity, :has_quantity?, to: :item

        def hidden?
          @hidden
        end

        def dom_id
          "order-item-#{catalog_id}"
        end

        def item_field_name
          "order[#{catalog_id}]"
        end

        def wrapper_classes
          class_names("hidden": hidden?)
        end

        def card_classes
          class_names(
            "card bg-base-100 border-2 transition-all duration-200",
            "border-accent bg-accent/10": has_quantity?,
            "border-base-300": !has_quantity?
          )
        end

        def stock_badge_text
          t(".stock_count", count: available_stock)
        end
      end
    end
  end
end
