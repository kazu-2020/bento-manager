# frozen_string_literal: true

class LocationsController < ApplicationController
  before_action :set_location, only: %i[show edit update]

  def index
    @locations = Location.display_order
  end

  def show
  end

  def new
    @location = Location.new

    respond_to do |format|
      format.turbo_stream
    end
  end

  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        @locations = Location.display_order
        format.turbo_stream
      else
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    render Locations::BasicInfoForm::Component.new(location: @location)
  end

  def update
    respond_to do |format|
      if @location.update(location_params)
        format.turbo_stream
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            Locations::BasicInfo::Component::FRAME_ID,
            Locations::BasicInfoForm::Component.new(location: @location)
          ), status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:name, :status)
  end
end
