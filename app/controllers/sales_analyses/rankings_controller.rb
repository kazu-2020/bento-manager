# frozen_string_literal: true

module SalesAnalyses
  class RankingsController < BaseController
    def show
      render SalesAnalyses::Ranking::Component.new(
        data: build_summary.ranking(limit: 5)
      ), layout: false
    end
  end
end
