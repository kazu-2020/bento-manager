# frozen_string_literal: true

require "test_helper"

module SalesAnalyses
  class RankingsControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      login_as_employee(:verified_employee)
    end

    test "認証済みユーザーが ranking にアクセスできる" do
      get sales_analyses_ranking_path(location_id: locations(:city_hall).id, period: 30)
      assert_response :success
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get sales_analyses_ranking_path(location_id: locations(:city_hall).id)
      assert_redirected_to "/employee/login"
    end
  end
end
