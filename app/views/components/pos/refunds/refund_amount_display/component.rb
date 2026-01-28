# frozen_string_literal: true

module Pos
  module Refunds
    module RefundAmountDisplay
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :has_selected_items?, :preview_refund_amount, to: :form

        def formatted_refund_amount
          helpers.number_to_currency(preview_refund_amount)
        end
      end
    end
  end
end
