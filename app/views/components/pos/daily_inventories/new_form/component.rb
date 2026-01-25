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

        delegate :items, :can_submit?, :selected_count,
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

        def render_bento_card(item)
          render BentoCard::Component.new(item: item)
        end
      end
    end
  end
end
