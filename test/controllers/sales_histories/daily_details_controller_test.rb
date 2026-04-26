# frozen_string_literal: true

require "test_helper"

module SalesHistories
  class DailyDetailsControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

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
