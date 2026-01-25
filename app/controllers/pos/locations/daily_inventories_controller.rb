# frozen_string_literal: true

module Pos
  module Locations
    class DailyInventoriesController < ApplicationController
      before_action :set_location
      before_action :set_catalogs

      def new
        @form = build_form
      end

      def create
        @form = build_form(inventory_params)

        creator = ::DailyInventories::BulkCreator.new(
          location: @location,
          inventory_params: @form.to_inventory_params
        )

        if creator.call
          redirect_to new_pos_location_sale_path(@location),
                      notice: t(".success", count: creator.created_count)
        else
          flash.now[:alert] = creator.error_message
          render :new, status: :unprocessable_entity
        end
      end

      private

      def set_location
        @location = Location.active.find(params[:location_id])
      end

      def set_catalogs
        @catalogs = Catalog.available.bento.order(:name)
      end

      def build_form(state = {})
        ::DailyInventories::InventoryForm.new(
          catalogs: @catalogs,
          state: state
        )
      end

      def inventory_params
        return {} unless params[:inventory]

        params[:inventory].to_unsafe_h.transform_values do |item|
          {
            selected: item[:selected] == "1",
            stock: item[:stock].to_i
          }
        end
      end
    end
  end
end
