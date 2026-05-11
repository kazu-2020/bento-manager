# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    class SalesHistoryControllerTest < ActionDispatch::IntegrationTest
      fixtures :employees, :locations, :catalogs, :catalog_prices,
               :sales, :sale_items, :coupons, :discounts, :sale_discounts

      setup do
        @location = locations(:city_hall)
        login_as_employee(:verified_employee)
      end

      test "認証済みユーザーが当日の販売履歴にアクセスできる" do
        get pos_location_sales_history_index_path(@location)

        assert_response :success
      end

      test "未認証ユーザーはログインページにリダイレクトされる" do
        reset!
        get pos_location_sales_history_index_path(@location)

        assert_redirected_to "/employee/login"
      end

      test "日次サマリーの売上合計はクーポン割引前の金額の合算になる" do
        # completed_sale fixture: 今日の販売、total_amount=550, final_amount=500（50円クーポン適用）
        get pos_location_sales_history_index_path(@location)

        summary = @controller.view_assigns["daily_summary"]

        assert_equal 1, summary[:total_count]
        assert_equal 550, summary[:total_amount], "クーポン割引前金額（total_amount）を合算するべき"
      end
    end
  end
end
