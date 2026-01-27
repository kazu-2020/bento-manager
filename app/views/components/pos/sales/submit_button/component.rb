# frozen_string_literal: true

module Pos
  module Sales
    module SubmitButton
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :has_items_in_cart?, :price_result, to: :form

        def disabled?
          !form.valid?
        end

        def submit_text
          if has_items_in_cart?
            t(".submit_with_total", total: final_total_display)
          else
            t(".submit_label")
          end
        end

        def final_total
          price_result[:final_total]
        end

        def final_total_display
          helpers.number_to_currency(final_total)
        end
      end
    end
  end
end
