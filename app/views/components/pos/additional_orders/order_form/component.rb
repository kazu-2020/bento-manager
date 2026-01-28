# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module OrderForm
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :items, :form_with_options, to: :form

        def render_item_card(item)
          render Pos::AdditionalOrders::OrderItemCard::Component.new(item: item)
        end
      end
    end
  end
end
