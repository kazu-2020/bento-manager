# frozen_string_literal: true

module SalesAnalyses
  class RankingsController < BaseController
    # 取得件数はそのまま表題の「TopN」になるため、集計とコンポーネントの両方に同じ値を渡す
    RANKING_LIMIT = 5

    def show
      render SalesAnalyses::Ranking::Component.new(
        data: build_summary.ranking(limit: RANKING_LIMIT),
        limit: RANKING_LIMIT
      ), layout: false
    end
  end
end
