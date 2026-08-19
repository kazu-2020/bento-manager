# frozen_string_literal: true

module SalesAnalyses
  class BaseController < ApplicationController
    include PeriodSanitizable

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
  end
end
