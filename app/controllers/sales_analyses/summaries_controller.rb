# frozen_string_literal: true

module SalesAnalyses
  class SummariesController < ApplicationController
    def show
      summary = build_summary
      render SalesAnalyses::SummaryCards::Component.new(
        data: summary.summary_by_customer_type
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
