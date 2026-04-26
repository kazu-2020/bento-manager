# frozen_string_literal: true

require "test_helper"

class SalesHistoriesControllerTest < ActionDispatch::IntegrationTest
  fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

  setup do
    login_as_employee(:verified_employee)
  end

  # --- index ---

  test "認証済みユーザーが index にアクセスできる" do
    get sales_histories_path
    assert_response :success
  end

  test "month パラメータで月を指定できる" do
    get sales_histories_path, params: { month: "2026-04" }
    assert_response :success
  end

  test "不正な month パラメータでも正常に動作する" do
    get sales_histories_path, params: { month: "invalid" }
    assert_response :success
  end

  # --- show ---

  test "認証済みユーザーが日別取引履歴にアクセスできる" do
    get sales_history_path(1.day.ago.to_date.to_s, location_id: locations(:city_hall).id)
    assert_response :success
  end

  test "不正な日付パラメータではリダイレクトされる" do
    get sales_history_path("invalid-date", location_id: locations(:city_hall).id)
    assert_redirected_to sales_histories_path
  end

  # --- 認証 ---

  test "未認証ユーザーはログインページにリダイレクトされる" do
    reset!
    get sales_histories_path
    assert_redirected_to "/employee/login"
  end
end
