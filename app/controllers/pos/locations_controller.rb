# frozen_string_literal: true

module Pos
  class LocationsController < ApplicationController
    def index
      @locations = Location.active.preload(:today_inventories).order(:name)
    end

    def show
      @location = Location.active.find(params[:id])

      if @location.has_today_inventory?
        redirect_to new_pos_location_sale_path(@location)
      else
        redirect_to new_pos_location_daily_inventory_path(@location)
      end
    end
  end
end
