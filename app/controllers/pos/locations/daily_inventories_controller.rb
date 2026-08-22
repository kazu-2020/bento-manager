# frozen_string_literal: true

module Pos
  module Locations
    class DailyInventoriesController < ApplicationController
      include DailyInventoryFormBuildable

      def new
        if @location.has_today_inventory?
          redirect_to new_pos_location_daily_inventories_correction_path(@location)
          return
        end

        @form = build_form
      end

      def create
        @form = build_form(submitted_params(:inventory, form: ::DailyInventories::InventoryForm))

        if @form.save
          redirect_to new_pos_location_sale_path(@location),
                      notice: t(".success", count: @form.created_count)
        else
          flash.now[:alert] = @form.errors.full_messages.first
          render :new, status: :unprocessable_entity
        end
      end
    end
  end
end
