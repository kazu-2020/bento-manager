# frozen_string_literal: true

module SalesAnalyses
  class CrossTablesController < BaseController
    def show
      render SalesAnalyses::CrossTable::Component.new(
        data: build_summary.cross_table
      ), layout: false
    end
  end
end
