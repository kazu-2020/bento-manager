# frozen_string_literal: true

require "test_helper"

class SalesAnalysesControllerTest < ActionDispatch::IntegrationTest
  fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

  setup do
    login_as_employee(:verified_employee)
  end

  test "認証済みユーザーが index にアクセスできる" do
    get sales_analyses_path
    assert_response :success
  end

  test "period パラメータを受け取る" do
    get sales_analyses_path, params: { period: 7 }
    assert_response :success
  end

  test "location_id パラメータを受け取る" do
    get sales_analyses_path, params: { location_id: locations(:city_hall).id }
    assert_response :success
  end

  test "未認証ユーザーはログインページにリダイレクトされる" do
    reset!
    get sales_analyses_path
    assert_redirected_to "/employee/login"
  end
end
