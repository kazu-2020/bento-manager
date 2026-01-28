# frozen_string_literal: true

module Pos
  module Sales
    module PriceBreakdown
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :has_items_in_cart?, :price_result, to: :form

        def items_with_prices
          price_result[:items_with_prices]
        end

        def subtotal
          price_result[:subtotal]
        end

        def discount_details
          price_result[:discount_details]
        end

        def total_discount_amount
          price_result[:total_discount_amount]
        end

        def final_total
          price_result[:final_total]
        end

        def has_discounts?
          discount_details.any? { |d| d[:applicable] }
        end

        def item_count
          items_with_prices.sum { |i| i[:quantity] }
        end

        def format_price(amount)
          helpers.number_to_currency(amount)
        end

        def bundle_price?(item)
          item[:catalog_price_id].present? &&
            item[:catalog].price_by_kind(:bundle)&.id == item[:catalog_price_id]
        end
      end
    end
  end
end
