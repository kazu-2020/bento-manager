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
                 :has_items_in_cart?, :submittable?, :discounts,
                 :form_with_options, :form_state_options, :price_result,
                 to: :form

        def location_name
          location.name
        end

        def back_url
          helpers.pos_location_path(location)
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

        def has_discounts?
          discounts.any?
        end
      end
    end
  end
end
