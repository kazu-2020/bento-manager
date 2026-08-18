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

        delegate :has_any_changes?, :preview, to: :form
        delegate :items_with_prices, :discount_details, to: :preview

        def has_corrected_items?
          items_with_prices.any?
        end

        def formatted_corrected_amount
          helpers.number_to_currency(preview.final_total)
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
