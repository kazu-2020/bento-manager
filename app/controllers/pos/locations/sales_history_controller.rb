# frozen_string_literal: true

module Pos
  module Locations
    class SalesHistoryController < ApplicationController
      include PosLocationScoped

      def index
        @sales = fetch_today_sales
        @daily_summary = calculate_daily_summary
      end

      private

      def fetch_today_sales
        @location.sales
                 .where(sale_datetime: Date.current.all_day)
                 .eager_load(:employee)
                 .preload(items: :catalog, sale_discounts: { discount: :discountable })
                 .order(sale_datetime: :desc)
      end

      # アプリケーションの想定では、1 日の売上集計は大量にならないため、メモリ上で集計する。
      # これによって、 3回のDBアクセスを1回に削減できる。
      def calculate_daily_summary
        completed_sales, voided_sales = @sales.partition(&:completed?)

        {
          total_count: completed_sales.size,
          total_amount: completed_sales.sum(&:total_amount),
          voided_count: voided_sales.size
        }
      end
    end
  end
end
