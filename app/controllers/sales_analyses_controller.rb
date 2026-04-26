# frozen_string_literal: true

class SalesAnalysesController < ApplicationController
  include LocationFindable

  def index
    render SalesAnalyses::IndexPage::Component.new(
      location: find_location,
      period: sanitize_period,
      locations: Location.display_order
    )
  end

  private

  def sanitize_period
    p = params[:period].to_i
    SalesAnalyses::FilterBar::Component::PERIODS.include?(p) ? p : 30
  end
end
