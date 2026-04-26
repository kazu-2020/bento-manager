# frozen_string_literal: true

module SalesAnalyses
  class CrossTablesController < ApplicationController
    def show
      summary = build_summary
      render SalesAnalyses::CrossTable::Component.new(
        data: summary.cross_table
      ), layout: false
    end

    private

    def build_summary
      location = Location.find(params[:location_id])
      period = (params[:period] || 30).to_i
      Sales::AnalysisSummary.new(
        location: location,
        from: period.days.ago.beginning_of_day,
        to: Time.current
      )
    end
  end
end
