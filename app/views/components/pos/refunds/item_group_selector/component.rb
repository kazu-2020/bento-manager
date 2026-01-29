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

        delegate :catalog_id, :catalog_name, :category, :total_quantity, :total_line_total,
                 :refund_quantity, :selected?, :single_price_type?, :items, to: :group

        def formatted_total_line_total
          helpers.number_to_currency(total_line_total)
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

        def quantity_field_id
          "catalog_#{catalog_id}_refund_quantity"
        end

        def quantity_field_name
          "refund[catalogs][#{catalog_id}][refund_quantity]"
        end

        def formatted_unit_price(item)
          helpers.number_to_currency(item.unit_price)
        end

        def price_type_label(item)
          item.bundle_price? ? I18n.t("pos.refunds.item_group_selector.bundle") : I18n.t("pos.refunds.item_group_selector.regular")
        end
      end
    end
  end
end
