# frozen_string_literal: true

module Pos
  module DailyInventories
    module NewForm
      class Component < Application::Component
        def initialize(location:, form:, back_url: nil, additional_order_quantities: {})
          @location = location
          @form = form
          @back_url = back_url
          @additional_order_quantities = additional_order_quantities
        end

        attr_reader :location, :form, :additional_order_quantities

        delegate :items, :bento_items, :side_menu_items, :valid?, :selected_count,
                 :form_with_options, :form_state_options, :search_query, to: :form

        def location_name
          location.name
        end

        def back_url
          @back_url || helpers.pos_locations_path
        end

        def today_date
          I18n.l(Date.current, format: :long)
        end

        def has_additional_orders?
          additional_ordered_items.any?
        end

        # 「日替わり弁当A +5個、サラダ +2個」
        def additional_orders_summary
          additional_ordered_items
            .map { |item, quantity| t(".additional_order_item", name: item.catalog_name, quantity: quantity) }
            .join("、")
        end

        # 追加発注のあった商品を、フォームに並ぶ順で返す
        def additional_ordered_items
          @additional_ordered_items ||= items.filter_map do |item|
            quantity = additional_order_quantities[item.catalog_id]
            [ item, quantity ] if quantity
          end
        end

        def has_items?
          items.any?
        end

        def has_bento_items?
          bento_items.any?
        end

        def has_side_menu_items?
          side_menu_items.any?
        end

        def render_item_card(item)
          render Pos::DailyInventories::NewFormItemCard::Component.new(item: item)
        end

        def render_submit_button
          render Pos::DailyInventories::NewFormSubmitButton::Component.new(
            disabled: !valid?,
            selected_count: selected_count
          )
        end

        def render_ghost_form
          render Pos::DailyInventories::NewFormGhostForm::Component.new(
            form_state_options: form_state_options,
            items: items,
            search_query: search_query
          )
        end

        def tab_items
          @tab_items ||= [
            (has_bento_items? ? { key: :bento, label: t(".bento_tab_label") } : nil),
            (has_side_menu_items? ? { key: :side_menu, label: t(".side_menu_tab_label") } : nil)
          ].compact
        end

        def items_for_tab(key)
          case key
          when :bento then bento_items
          when :side_menu then side_menu_items
          else []
          end
        end
      end
    end
  end
end
