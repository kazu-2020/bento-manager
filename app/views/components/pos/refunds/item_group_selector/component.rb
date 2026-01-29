# frozen_string_literal: true

module Pos
  module Refunds
    module ItemGroupSelector
      class Component < Application::Component
        def initialize(group:, form:)
          @group = group
          @form = form
        end

        attr_reader :group, :form

        delegate :catalog_id, :catalog_name, :total_quantity, :total_line_total,
                 :refund_quantity, :selected?, to: :group

        def formatted_total_line_total
          helpers.number_to_currency(total_line_total)
        end

        def quantity_field_id
          "catalog_#{catalog_id}_refund_quantity"
        end

        def quantity_field_name
          "refund[catalogs][#{catalog_id}][refund_quantity]"
        end
      end
    end
  end
end
