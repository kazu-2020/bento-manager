# frozen_string_literal: true

module Pos
  module Refunds
    module SettlementSummary
      class Component < Application::Component
        def initialize(form:, sale:)
          @form = form
          @sale = sale
        end

        attr_reader :form, :sale

        delegate :has_any_changes?, :all_items_zero?, :preview_price_result, to: :form

        def items_with_prices
          @items_with_prices ||= preview_price_result&.dig(:items_with_prices) || []
        end

        def has_corrected_items?
          items_with_prices.any?
        end

        def formatted_corrected_amount
          return helpers.number_to_currency(0) if all_items_zero?

          amount = preview_price_result&.dig(:final_total) || 0
          helpers.number_to_currency(amount)
        end

        def discount_details
          @discount_details ||= preview_price_result&.dig(:discount_details) || []
        end

        def applied_discounts
          discount_details.select { |d| d[:quantity].to_i > 0 }
        end

        def returned_coupons
          discount_details
            .select { |d| d[:requested_quantity].to_i > d[:quantity].to_i }
            .map do |d|
              {
                name: d[:discount_name],
                quantity: d[:requested_quantity].to_i - d[:quantity].to_i
              }
            end
        end

        def any_returned_coupons?
          returned_coupons.any?
        end
      end
    end
  end
end
