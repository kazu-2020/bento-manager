# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class FormStatesController < ApplicationController
        before_action :set_location
        before_action :set_catalogs

        def create
          @form = build_form(parse_inventory_params(:ghost_inventory))

          respond_to do |format|
            format.turbo_stream { render "pos/locations/daily_inventories/form_state" }
            format.html { render "pos/locations/daily_inventories/new" }
          end
        end

        private

        def set_location
          @location = Location.active.find(params[:location_id])
        end

        def set_catalogs
          @catalogs = Catalog.available.bento.includes(:prices).order(:name)
        end

        def build_form(state = {})
          ::DailyInventories::InventoryForm.new(location: @location, catalogs: @catalogs, state: state)
        end

        def parse_inventory_params(key)
          return {} unless params[key]

          params[key].to_unsafe_h.transform_values do |item|
            { selected: item[:selected] == "1", stock: item[:stock].to_i }
          end
        end
      end
    end
  end
end
