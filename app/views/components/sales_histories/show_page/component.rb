# frozen_string_literal: true

module SalesHistories
  module ShowPage
    class Component < Application::Component
      def initialize(date:, location:, sales:)
        @date = date
        @location = location
        @sales = sales
      end

      private

      attr_reader :date, :location, :sales

      # タイトルとパンくずは同じ画面を指す。片方だけ変えると画面の呼び名が割れる
      def screen_name
        "弁当販売履歴"
      end

      def back_path
        helpers.sales_histories_path(
          month: date.strftime("%Y-%m"),
          location_id: location.id
        )
      end

      def completed_sales
        @completed_sales ||= sales.select(&:completed?)
      end

      def total_amount
        completed_sales.sum(&:total_amount)
      end

      def total_transactions
        completed_sales.size
      end
    end
  end
end
