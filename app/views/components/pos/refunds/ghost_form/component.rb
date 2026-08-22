# frozen_string_literal: true

module Pos
  module Refunds
    module GhostForm
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :form_state_options, :corrected_items, :coupon_quantities,
                 :available_discounts, to: :form
      end
    end
  end
end
