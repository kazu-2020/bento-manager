# frozen_string_literal: true

module SalesHistories
  module ShowPage
    class Component < Application::Component
      def initialize(date:, location:, sales:, total_quantity:, total_transactions:)
        @date = date
        @location = location
        @sales = sales
        @total_quantity = total_quantity
        @total_transactions = total_transactions
      end

      private

      attr_reader :date, :location, :sales, :total_quantity, :total_transactions

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
    end
  end
end
