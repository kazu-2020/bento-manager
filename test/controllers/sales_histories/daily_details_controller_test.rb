# frozen_string_literal: true

require "test_helper"

module SalesHistories
  class DailyDetailsControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items,
             :coupons, :discounts, :sale_discounts

    setup do
      login_as_employee(:verified_employee)
    end

    test "認証済みユーザーが daily_detail にアクセスできる" do
      get sales_histories_daily_detail_path(
        location_id: locations(:city_hall).id,
        date: 1.day.ago.to_date.to_s
      )

      assert_response :success
    end

    test "日別合計はクーポン割引前の金額を合算する" do
      # completed_sale fixture: 今日の販売、total_amount=550, final_amount=500（50円クーポン適用）
      get sales_histories_daily_detail_path(
        location_id: locations(:city_hall).id,
        date: Date.current.to_s
      )

      assert_response :success
      assert_match "550", response.body
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get sales_histories_daily_detail_path(
        location_id: locations(:city_hall).id,
        date: Date.current.to_s
      )

      assert_redirected_to "/employee/login"
    end
  end
end
