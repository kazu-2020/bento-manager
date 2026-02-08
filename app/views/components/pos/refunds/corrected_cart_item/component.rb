# frozen_string_literal: true

module Pos
  module Refunds
    module CorrectedCartItem
      class Component < Application::Component
        with_collection_parameter :item

        def initialize(item:)
          @item = item
        end

        attr_reader :item

        delegate :catalog_id, :catalog_name, :quantity, :original_quantity,
                 :max_quantity, :in_cart?, :changed?, :sold_out?, to: :item

        def dom_id
          "corrected-item-#{catalog_id}"
        end

        def quantity_field_name
          "refund[corrected][#{catalog_id}][quantity]"
        end

        def card_classes
          class_names(
            "card bg-base-100 border-2 transition-all duration-200",
            "border-accent bg-accent/10": changed?,
            "border-base-300": !changed?,
            "opacity-50": sold_out?
          )
        end

        def unit_price_display
          price = item.unit_price
          return nil unless price

          helpers.number_to_currency(price)
        end

        def stock_badge_text
          t(".stock_count", count: max_quantity)
        end

        def original_badge_text
          t(".original_quantity", count: original_quantity)
        end

        def show_original_badge?
          original_quantity > 0
        end
      end
    end
  end
end
