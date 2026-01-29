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

        delegate :catalog_name, :quantity, :unit_price, :line_total, :category, :selected?,
                 :refund_quantity, to: :item

        def quantity_field_id
          "item_#{item.id}_refund_quantity"
        end

        def quantity_field_name
          "refund[items][#{item.id}][refund_quantity]"
        end

        def formatted_unit_price
          helpers.number_to_currency(unit_price)
        end

        def formatted_line_total
          helpers.number_to_currency(line_total)
        end

        def category_badge_class
          case category
          when "bento"
            "badge-primary"
          else
            "badge-secondary"
          end
        end

        def category_label
          I18n.t("enums.catalog.category.#{category}")
        end
      end
    end
  end
end
