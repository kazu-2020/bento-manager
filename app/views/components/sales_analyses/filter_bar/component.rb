# frozen_string_literal: true

module SalesAnalyses
  module FilterBar
    class Component < Application::Component
      def initialize(location:, period:, locations:)
        @location = location
        @period = period
        @locations = locations
      end

      private

      attr_reader :location, :period, :locations

      def days_options
        Sales::AnalysisPeriod::ALLOWED_DAYS
      end

      def days_class(days)
        days == period.days ? "btn btn-sm btn-primary join-item" : "btn btn-sm btn-ghost join-item"
      end

      def days_path(days)
        helpers.sales_analyses_path(days: days, location_id: location.id)
      end

      def location_path(loc_id)
        helpers.sales_analyses_path(days: period.days, location_id: loc_id)
      end

      def period_label
        "#{helpers.l(period.first_date)} 〜 #{helpers.l(period.last_date)}"
      end
    end
  end
end
