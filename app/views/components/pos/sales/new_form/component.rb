# frozen_string_literal: true

module Pos
  module Sales
    module NewForm
      class Component < Application::Component
        def initialize(location:, form:)
          @location = location
          @form = form
        end

        attr_reader :location, :form

        delegate :items, :bento_items, :side_menu_items, :cart_items,
                 :has_items_in_cart?, :discounts,
                 :form_with_options, :form_state_options, :price_result,
                 to: :form

        def has_bento_items?
          bento_items.any?
        end

        def has_side_menu_items?
          side_menu_items.any?
        end

        def has_discounts?
          discounts.any?
        end

        def tab_items
          @tab_items ||= begin
            items = []
            items << { key: :bento, label: t(".bento_section_title") } if has_bento_items?
            items << { key: :side_menu, label: t(".side_menu_section_title") } if has_side_menu_items?
            items << { key: :coupon, label: t(".coupon_tab_label") } if has_discounts?
            items
          end
        end
      end
    end
  end
end
