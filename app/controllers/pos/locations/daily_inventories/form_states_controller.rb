# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class FormStatesController < ApplicationController
        before_action :set_location
        before_action :set_catalogs

        def create
          @form = build_form(submitted_params(:ghost_inventory))

          respond_to do |format|
            format.turbo_stream
          end
        end

        private

        def set_location
          @location = Location.active.find(params[:location_id])
        end

        def set_catalogs
          @catalogs = Catalog.available.category_order
        end

        def build_form(submitted = {})
          ::DailyInventories::InventoryForm.new(location: @location, catalogs: @catalogs, submitted: submitted)
        end

        def submitted_params(key)
          return {} unless params[key]

          params[key].to_unsafe_h
        end
      end
    end
  end
end
