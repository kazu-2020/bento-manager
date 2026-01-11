# frozen_string_literal: true

class LocationCardComponent < ApplicationComponent
  def initialize(location:)
    @location = location
  end

  attr_reader :location

  def show_path
    helpers.location_path(location)
  end
end
