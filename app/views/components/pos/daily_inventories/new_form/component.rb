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

        delegate :items, :can_submit?, :selected_count, to: :form

        def location_name
          location.name
        end

        def today_date
          I18n.l(Date.current, format: :long)
        end

        def form_url
          helpers.pos_location_daily_inventories_path(location)
        end

        def form_state_url
          helpers.pos_location_daily_inventories_form_state_path(location)
        end

        def back_url
          helpers.pos_locations_path
        end

        def has_items?
          items.any?
        end

        def render_bento_card(item)
          render BentoCard::Component.new(item: item)
        end
      end
    end
  end
end
