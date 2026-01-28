# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module NewPage
      class Component < Application::Component
        def initialize(location:, form:)
          @location = location
          @form = form
        end

        attr_reader :location, :form

        def render_order_form
          render Pos::AdditionalOrders::OrderForm::Component.new(form: form)
        end
      end
    end
  end
end
