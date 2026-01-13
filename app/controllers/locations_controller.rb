# frozen_string_literal: true

class LocationsController < ApplicationController
  before_action :set_location, only: %i[show edit update destroy]

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
    if @location.update(location_params)
      render turbo_stream: turbo_stream.replace(
        Locations::BasicInfo::Component::FRAME_ID,
        Locations::BasicInfo::Component.new(location: @location)
      )
    else
      render turbo_stream: turbo_stream.replace(
        Locations::BasicInfo::Component::FRAME_ID,
        Locations::BasicInfoForm::Component.new(location: @location)
      ), status: :unprocessable_entity
    end
  end

  def destroy
    @location.inactive!
    redirect_to locations_path, notice: t("locations.destroy.success")
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:name, :status)
  end
end
