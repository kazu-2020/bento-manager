# frozen_string_literal: true

require "test_helper"

module SalesAnalyses
  class SummariesControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      login_as_employee(:verified_employee)
    end

    test "認証済みユーザーが summary にアクセスできる" do
      get sales_analyses_summary_path(location_id: locations(:city_hall).id, period: 30)

      assert_response :success
    end

    test "PERIODS にない period を渡すと 30 日として扱われる" do
      city_hall = locations(:city_hall)

      get sales_analyses_summary_path(location_id: city_hall.id, period: 999)
      fallback_body = response.body

      get sales_analyses_summary_path(location_id: city_hall.id, period: 30)

      assert_equal response.body, fallback_body

      get sales_analyses_summary_path(location_id: city_hall.id, period: 7)

      assert_not_equal response.body, fallback_body
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get sales_analyses_summary_path(location_id: locations(:city_hall).id)

      assert_redirected_to "/employee/login"
    end
  end
end
