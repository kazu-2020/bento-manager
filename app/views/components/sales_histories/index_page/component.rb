# frozen_string_literal: true

module SalesHistories
  module IndexPage
    class Component < Application::Component
      def initialize(location:, month:, calendar:, locations:)
        @location = location
        @month = month
        @calendar = calendar
        @locations = locations
      end

      private

      attr_reader :location, :month, :calendar, :locations

      def selected_date
        month.month == Date.current.month && month.year == Date.current.year ? Date.current : month.end_of_month
      end

      def daily_detail_src
        helpers.sales_histories_daily_detail_path(
          location_id: location.id,
          date: selected_date.to_s
        )
      end

      def prev_month_path
        helpers.sales_histories_path(month: month.prev_month.strftime("%Y-%m"), location_id: location.id)
      end

      def next_month_path
        helpers.sales_histories_path(month: month.next_month.strftime("%Y-%m"), location_id: location.id)
      end

      def current_month_path
        helpers.sales_histories_path(location_id: location.id)
      end

      def location_path(loc_id)
        helpers.sales_histories_path(month: month.strftime("%Y-%m"), location_id: loc_id)
      end
    end
  end
end
