# frozen_string_literal: true

class SalesAnalysesController < ApplicationController
  include LocationFindable

  def index
    render SalesAnalyses::IndexPage::Component.new(
      location: find_location,
      period: (params[:period] || 30).to_i,
      locations: Location.display_order
    )
  end
end
