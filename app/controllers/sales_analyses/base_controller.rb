# frozen_string_literal: true

module SalesAnalyses
  class BaseController < ApplicationController
    private

    def build_summary
      period = Sales::AnalysisPeriod.from_param(params[:days])
      Sales::AnalysisSummary.new(
        location: Location.find(params[:location_id]),
        from: period.from,
        to: period.to
      )
    end
  end
end
