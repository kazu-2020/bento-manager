# frozen_string_literal: true

require "test_helper"

class SalesHistoriesControllerTest < ActionDispatch::IntegrationTest
  include SaleTestHelper

  # 集計対象は自分で作る。共有フィクスチャを数えると他テストクラスの販売が混ざる
  fixtures :employees, :catalogs, :catalog_prices

  SALAD_ONLY_ON = Date.new(2026, 3, 5)

  setup do
    login_as_employee(:verified_employee)
    @location = Location.create!(name: "弁当販売履歴テスト販売先", status: :active)
  end

  # --- index ---

  test "認証済みユーザーが弁当販売履歴を開ける" do
    get sales_histories_path

    assert_response :success
    assert_select "title", "弁当販売履歴"
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

  test "認証済みユーザーが日別の弁当販売履歴を開ける" do
    get sales_history_path(Date.current.to_s, location_id: @location.id)

    assert_response :success
    assert_select "title", /\A弁当販売履歴 /
    assert_select ".breadcrumbs a", "弁当販売履歴"
  end

  test "サラダしか売れなかった日は弁当0個と表示し、取引一覧にはサラダを金額つきで並べる" do
    sale = create_sale(
      location: @location,
      customer_type: :citizen,
      sale_datetime: SALAD_ONLY_ON.in_time_zone.change(hour: 12)
    )
    create_sale_item(sale: sale, quantity: 1, catalog_price: catalog_prices(:salad_regular))

    get sales_history_path(SALAD_ONLY_ON.to_s, location_id: @location.id)

    assert_response :success
    assert_select "p.text-2xl", text: "0個"
    assert_select "table tbody tr td", text: "サラダ"
    assert_select "table tbody tr td", text: "¥550"
  end

  test "不正な日付パラメータではリダイレクトされる" do
    get sales_history_path("invalid-date", location_id: @location.id)

    assert_redirected_to sales_histories_path
  end

  # --- 認証 ---

  test "未認証ユーザーはログインページにリダイレクトされる" do
    reset!
    get sales_histories_path

    assert_redirected_to "/employee/login"
  end
end
