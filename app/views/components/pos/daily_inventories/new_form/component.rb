# frozen_string_literal: true

module Pos
  module DailyInventories
    module NewForm
      class Component < Application::Component
        def initialize(location:, form:)
          @location = location
          @form = form
        end

        attr_reader :location, :form

        delegate :items, :bento_items, :side_menu_items, :valid?, :selected_count,
                 :form_with_options, :form_state_options, to: :form

        def location_name
          location.name
        end

        def back_url
          helpers.pos_locations_path
        end

        def today_date
          I18n.l(Date.current, format: :long)
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
            items: items
          )
        end

        def tab_items
          @tab_items ||= begin
            items = []
            items << { key: :bento, label: t(".bento_tab_label") } if has_bento_items?
            items << { key: :side_menu, label: t(".side_menu_tab_label") } if has_side_menu_items?
            items
          end
        end
      end
    end
  end
end
