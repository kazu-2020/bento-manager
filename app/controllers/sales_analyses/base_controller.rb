# frozen_string_literal: true

module SalesAnalyses
  class BaseController < ApplicationController
    private

    def build_summary
      Sales::AnalysisSummary.new(
        location: Location.find(params[:location_id]),
        period: Sales::AnalysisPeriod.from_param(params[:days])
      )
    end
  end
end
