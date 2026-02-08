# frozen_string_literal: true

module Pos
  module Refunds
    module AddableItemSelector
      class Component < Application::Component
        def initialize(addable_item:, form:)
          @addable_item = addable_item
          @form = form
        end

        attr_reader :addable_item, :form

        delegate :catalog_id, :catalog_name, :add_quantity, :max_addable,
                 :sold_out?, :selected?, to: :addable_item

        def quantity_field_id
          "catalog_#{catalog_id}_add_quantity"
        end

        def quantity_field_name
          "refund[additions][#{catalog_id}][add_quantity]"
        end

        def formatted_stock
          sold_out? ? t(".sold_out") : t(".available_stock", count: max_addable)
        end
      end
    end
  end
end
