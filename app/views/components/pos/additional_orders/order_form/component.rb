# frozen_string_literal: true

module Pos
  module AdditionalOrders
    module OrderForm
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :items, :form_with_options, :form_state_options,
                 :inventory_items, :non_inventory_items, :search_query, to: :form

        def show_tabs?
          inventory_items.any? && non_inventory_items.any?
        end

        def render_item_card(item)
          render Pos::AdditionalOrders::OrderItemCard::Component.new(item: item)
        end

        def render_ghost_form
          render Pos::AdditionalOrders::OrderFormGhostForm::Component.new(
            form_state_options: form_state_options,
            items: items,
            search_query: search_query
          )
        end
      end
    end
  end
end
