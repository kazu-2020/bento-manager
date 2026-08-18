# frozen_string_literal: true

module Pos
  module Sales
    module GhostForm
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :form_state_options, :items, :discounts, :coupon_quantity, to: :form
      end
    end
  end
end
