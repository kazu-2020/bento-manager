# frozen_string_literal: true

class SalesAnalysesController < ApplicationController
  include LocationFindable
  include PeriodSanitizable

  def index
    render SalesAnalyses::IndexPage::Component.new(
      location: find_location,
      period: sanitize_period,
      locations: Location.display_order
    )
  end
end
