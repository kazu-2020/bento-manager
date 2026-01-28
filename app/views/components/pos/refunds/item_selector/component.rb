# frozen_string_literal: true

module Pos
  module Refunds
    module ItemSelector
      class Component < Application::Component
        def initialize(item:, form:)
          @item = item
          @form = form
        end

        attr_reader :item, :form

        def checkbox_id
          "item_#{item.id}_refund"
        end

        def field_name
          "refund[items][#{item.id}][refund]"
        end

        def catalog_name
          item.catalog_name
        end

        def quantity
          item.quantity
        end

        def unit_price
          item.unit_price
        end

        def line_total
          item.line_total
        end

        def formatted_unit_price
          helpers.number_to_currency(unit_price)
        end

        def formatted_line_total
          helpers.number_to_currency(line_total)
        end

        def selected?
          item.selected?
        end

        def category_badge_class
          case item.category
          when "bento"
            "badge-primary"
          else
            "badge-secondary"
          end
        end

        def category_label
          I18n.t("enums.catalog.category.#{item.category}")
        end
      end
    end
  end
end
