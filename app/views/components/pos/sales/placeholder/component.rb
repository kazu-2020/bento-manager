# frozen_string_literal: true

module Pos
  module Sales
    module Placeholder
      class Component < Application::Component
        def initialize(location:, inventories:)
          @location = location
          @inventories = inventories
        end

        attr_reader :location, :inventories

        def location_name
          location.name
        end

        def back_url
          helpers.pos_locations_path
        end

        def edit_inventory_url
          helpers.new_pos_location_daily_inventory_path(location)
        end
      end
    end
  end
end
