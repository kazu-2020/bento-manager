# frozen_string_literal: true

module Pos
  module Locations
    class SalesHistoryController < ApplicationController
      before_action :set_location

      def index
        @sales = fetch_today_sales
        @daily_summary = calculate_daily_summary
      end

      private

      def set_location
        @location = Location.active.find(params[:location_id])
      end

      def fetch_today_sales
        @location.sales
                 .where(sale_datetime: Date.current.all_day)
                 .preload(:sale_discounts, items: :catalog,)
                 .order(sale_datetime: :desc)
      end

      # アプリケーションの想定では、1 日の売上集計は大量にならないため、メモリ上で集計する。
      # これによって、 3回のDBアクセスを1回に削減できる。
      def calculate_daily_summary
        completed_sales, voided_sales = @sales.partition(&:completed?)

        {
          total_count: completed_sales.size,
          total_amount: completed_sales.sum(&:final_amount),
          voided_count: voided_sales.size
        }
      end
    end
  end
end
