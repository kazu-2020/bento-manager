# frozen_string_literal: true

module Pos
  module Sales
    module ProductCard
      class Component < Application::Component
        def initialize(item:)
          @item = item
        end

        attr_reader :item

        delegate :catalog_id, :catalog_name, :stock, :quantity, :in_cart?, :sold_out?, to: :item

        def dom_id
          "cart-item-#{catalog_id}"
        end

        def item_field_name
          "cart[#{catalog_id}]"
        end

        def card_classes
          class_names(
            "card bg-base-100 border-2 transition-all duration-200",
            "border-accent bg-accent/10": in_cart?,
            "border-base-300": !in_cart?,
            "opacity-50": sold_out?
          )
        end

        def unit_price_display
          price = item.unit_price
          return nil unless price

          helpers.number_to_currency(price)
        end

        def stock_badge_text
          t(".stock_count", count: stock)
        end
      end
    end
  end
end
