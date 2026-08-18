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

        delegate :has_any_changes?, to: :form
        delegate :preview, to: :form, private: true
        delegate :items_with_prices, :discount_details, :final_total, to: :preview

        def has_corrected_items?
          items_with_prices.any?
        end

        def formatted_corrected_amount
          helpers.number_to_currency(final_total)
        end

        def applied_discounts
          discount_details.select { |d| d[:quantity].to_i > 0 }
        end
      end
    end
  end
end
