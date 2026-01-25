# frozen_string_literal: true

module Pos
  class LocationsController < ApplicationController
    def index
      @locations = Location.active.preload(:today_inventories).order(:name)
    end
  end
end
