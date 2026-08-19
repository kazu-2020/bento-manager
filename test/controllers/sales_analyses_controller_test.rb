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

  test "days パラメータを受け取る" do
    get sales_analyses_path, params: { days: 7 }

    assert_response :success
  end

  test "対応していない集計日数を指定すると過去30日として扱われる" do
    get sales_analyses_path, params: { days: 999 }

    assert_select "turbo-frame#sales_analysis_summary[src*=?]", "days=30"
  end

  # days[]=7 のように配列やハッシュで渡されても、正規化は既定値に落ちて 500 にしない
  test "集計日数が数値以外の形で渡されても過去30日として扱われる" do
    get sales_analyses_path, params: { days: [ "7" ] }

    assert_response :success
    assert_select "turbo-frame#sales_analysis_summary[src*=?]", "days=30"
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
