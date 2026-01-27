# frozen_string_literal: true

module Pos
  module Sales
    module GhostForm
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :form_state_options, :items, :discounts, :customer_type, to: :form

        def coupon_quantity(discount)
          form.coupon_quantity(discount)
        end
      end
    end
  end
end
