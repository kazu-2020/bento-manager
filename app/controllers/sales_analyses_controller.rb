# frozen_string_literal: true

class SalesAnalysesController < ApplicationController
  def index
    render SalesAnalyses::IndexPage::Component.new(
      location: find_location,
      period: (params[:period] || 30).to_i,
      locations: Location.display_order
    )
  end

  private

  def find_location
    if params[:location_id].present?
      Location.find(params[:location_id])
    else
      Location.display_order.first
    end
  end
end
