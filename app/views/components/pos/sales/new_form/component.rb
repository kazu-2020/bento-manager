# frozen_string_literal: true

module Pos
  module Sales
    module NewForm
      class Component < Application::Component
        def initialize(location:, form:, re_registerable: false)
          @location = location
          @form = form
          @re_registerable = re_registerable
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

        def re_registerable?
          @re_registerable
        end

        def correction_url
          helpers.new_pos_location_daily_inventories_correction_path(location)
        end

        def sales_history_url
          helpers.pos_location_sales_history_index_path(location)
        end
      end
    end
  end
end
