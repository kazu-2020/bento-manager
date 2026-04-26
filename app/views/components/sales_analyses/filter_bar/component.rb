# frozen_string_literal: true

module SalesAnalyses
  module FilterBar
    class Component < Application::Component
      PERIODS = [ 7, 30, 90 ].freeze

      def initialize(location:, period:, locations:)
        @location = location
        @period = period
        @locations = locations
      end

      private

      attr_reader :location, :period, :locations

      def period_options
        PERIODS
      end

      def period_class(p)
        base = "btn btn-sm"
        p == period ? "#{base} btn-primary" : "#{base} btn-ghost"
      end

      def period_path(p)
        helpers.sales_analyses_path(period: p, location_id: location.id)
      end

      def location_path(loc_id)
        helpers.sales_analyses_path(period: period, location_id: loc_id)
      end
    end
  end
end
