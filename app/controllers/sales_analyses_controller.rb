# frozen_string_literal: true

class SalesAnalysesController < ApplicationController
  include LocationFindable

  def index
    render SalesAnalyses::IndexPage::Component.new(
      location: find_location,
      period: Sales::AnalysisPeriod.from_param(params[:days]),
      locations: Location.display_order
    )
  end
end
