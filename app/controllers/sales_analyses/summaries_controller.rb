# frozen_string_literal: true

module SalesAnalyses
  class SummariesController < BaseController
    def show
      render SalesAnalyses::SummaryCards::Component.new(
        data: build_summary.summary_by_customer_type
      ), layout: false
    end
  end
end
