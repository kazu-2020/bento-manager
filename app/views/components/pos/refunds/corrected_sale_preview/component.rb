# frozen_string_literal: true

module Pos
  module Refunds
    module CorrectedSalePreview
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :remaining_items, :has_selected_items?, :all_items_selected?,
                 :preview_price_result, to: :form

        def has_remaining_items?
          items_with_prices.any?
        end

        def items_with_prices
          @items_with_prices ||= preview_price_result&.dig(:items_with_prices) || []
        end

        def formatted_corrected_amount
          return helpers.number_to_currency(0) if all_items_selected?

          amount = preview_price_result&.dig(:final_total) || 0
          helpers.number_to_currency(amount)
        end
      end
    end
  end
end
