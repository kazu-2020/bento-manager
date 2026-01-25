# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class FormStatesController < ApplicationController
        before_action :set_location
        before_action :set_catalogs

        # Ghost Form からの画面更新リクエスト
        def create
          @form = build_form(ghost_inventory_params)

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
          ::DailyInventories::InventoryForm.new(
            catalogs: @catalogs,
            state: state
          )
        end

        def ghost_inventory_params
          return {} unless params[:ghost_inventory]

          params[:ghost_inventory].to_unsafe_h.transform_values do |item|
            {
              selected: item[:selected] == "1",
              stock: item[:stock].to_i
            }
          end
        end
      end
    end
  end
end
