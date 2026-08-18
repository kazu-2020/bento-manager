# frozen_string_literal: true

module Pos
  module Locations
    module DailyInventories
      class FormStatesController < ApplicationController
        include SubmittedParamsFilterable

        before_action :set_location
        before_action :set_catalogs

        def create
          @form = build_form(submitted_params(:ghost_inventory, form: ::DailyInventories::InventoryForm))

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

        def build_form(submitted)
          items = ::DailyInventories::ItemBuilder.from_params(@catalogs, submitted.values)
          ::DailyInventories::InventoryForm.new(
            location: @location, items: items,
            search_query: params[:search_query], submitted: submitted
          )
        end
      end
    end
  end
end
