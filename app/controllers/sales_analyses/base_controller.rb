# frozen_string_literal: true

module SalesAnalyses
  class BaseController < ApplicationController
    private

    def build_summary
      location = Location.find(params[:location_id])
      period = sanitize_period
      Sales::AnalysisSummary.new(
        location: location,
        from: period.days.ago.beginning_of_day,
        to: Time.current
      )
    end

    def sanitize_period
      p = params[:period].to_i
      SalesAnalyses::FilterBar::Component::PERIODS.include?(p) ? p : 30
    end
  end
end
