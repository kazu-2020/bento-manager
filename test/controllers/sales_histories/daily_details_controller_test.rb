# frozen_string_literal: true

require "test_helper"

module SalesHistories
  class DailyDetailsControllerTest < ActionDispatch::IntegrationTest
    include SaleTestHelper

    # 集計対象は自分で作る。共有フィクスチャを数えると他テストクラスの販売が混ざる
    fixtures :employees, :catalogs, :catalog_prices

    SOLD_ON = Date.new(2026, 3, 2)
    SALAD_ONLY_ON = Date.new(2026, 3, 5)

    setup do
      login_as_employee(:verified_employee)
      @location = Location.create!(name: "日別詳細テスト販売先", status: :active)

      # 3/2: 弁当A x2、弁当B x1 の 2 取引
      sell(on: SOLD_ON, quantity: 2)
      sell(on: SOLD_ON, quantity: 1, catalog_price: catalog_prices(:daily_bento_b_regular))

      # 3/5: サラダ x1 のみの 1 取引
      sell(on: SALAD_ONLY_ON, quantity: 1, catalog_price: catalog_prices(:salad_regular))
    end

    test "選択日の弁当の販売数と取引件数を表示する" do
      get_detail(SOLD_ON)

      assert_response :success
      assert_select "p.text-xl", text: "3個"
      assert_select "p.text-xl", text: "2件"
    end

    test "サラダしか売れなかった日は弁当0個として表示し、内訳にサラダを並べない" do
      get_detail(SALAD_ONLY_ON)

      assert_response :success
      assert_select "p.text-xl", text: "0個"
      assert_select "p.text-xl", text: "1件"
      assert_no_match(/サラダ/, response.body)
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get_detail(SOLD_ON)

      assert_redirected_to "/employee/login"
    end

    private

    def get_detail(date)
      get sales_histories_daily_detail_path(location_id: @location.id, date: date.to_s)
    end

    def sell(on:, quantity:, catalog_price: catalog_prices(:daily_bento_a_regular))
      sale = create_sale(
        location: @location,
        customer_type: :staff,
        sale_datetime: on.in_time_zone.change(hour: 12)
      )
      create_sale_item(sale: sale, quantity: quantity, catalog_price: catalog_price)
    end
  end
end
