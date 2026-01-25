# frozen_string_literal: true

module Pos
  module Locations
    class SalesController < ApplicationController
      before_action :set_location

      def new
        @inventories = @location.today_inventories.includes(:catalog).order("catalogs.name")
      end

      private

      def set_location
        @location = Location.active.find(params[:location_id])
      end
    end
  end
end
