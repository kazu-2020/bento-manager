# frozen_string_literal: true

module Pos
  module Refunds
    module CorrectedSalePreview
      class Component < Application::Component
        def initialize(form:, sale: nil)
          @form = form
          @sale = sale
        end

        attr_reader :form, :sale

        delegate :remaining_items, :has_any_changes?, :all_items_selected?,
                 :preview_price_result, to: :form

        def has_remaining_items?
          items_with_prices.any?
        end

        def items_with_prices
          @items_with_prices ||= preview_price_result&.dig(:items_with_prices) || []
        end

        def formatted_corrected_amount
          return helpers.number_to_currency(0) if all_items_selected? && !form.has_additions?

          amount = preview_price_result&.dig(:final_total) || 0
          helpers.number_to_currency(amount)
        end

        def discount_details
          @discount_details ||= preview_price_result&.dig(:discount_details) || []
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

        def added_item?(item)
          return false unless sale
          !original_catalog_ids.include?(item[:catalog].id)
        end

        private

        def original_catalog_ids
          @original_catalog_ids ||= sale.items.map(&:catalog_id).uniq
        end
      end
    end
  end
end
