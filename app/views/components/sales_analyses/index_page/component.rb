# frozen_string_literal: true

module SalesAnalyses
  module IndexPage
    class Component < Application::Component
      def initialize(location:, period:, locations:)
        @location = location
        @period = period
        @locations = locations
      end

      private

      attr_reader :location, :period, :locations

      def filter_params
        { location_id: location.id, period: period }
      end

      def summary_src
        helpers.sales_analyses_summary_path(**filter_params)
      end

      def ranking_src
        helpers.sales_analyses_ranking_path(**filter_params)
      end

      def cross_table_src
        helpers.sales_analyses_cross_table_path(**filter_params)
      end
    end
  end
end
