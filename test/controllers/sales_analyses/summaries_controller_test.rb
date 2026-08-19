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

    # 過去30日には入るが過去7日には入らない販売を 1 件混ぜ、集計期間が
    # 実際に効いていることごと確かめる。共有フィクスチャを集計すると
    # 他のテストクラスのレコードが混入するため、専用の販売先を作る
    test "対応していない集計期間を指定すると過去30日として扱われる" do
      location = Location.create!(name: "集計期間フォールバック検証販売先", status: :active)
      record_bento_sale(location: location, sold_at: 20.days.ago)
      record_bento_sale(location: location, sold_at: 1.day.ago)

      get sales_analyses_summary_path(location_id: location.id, period: 999)

      assert_select "p.text-staff", text: "2個"

      get sales_analyses_summary_path(location_id: location.id, period: 7)

      assert_select "p.text-staff", text: "1個"
    end

    test "未認証ユーザーはリダイレクトされる" do
      reset!
      get sales_analyses_summary_path(location_id: locations(:city_hall).id)

      assert_redirected_to "/employee/login"
    end

    private

    def record_bento_sale(location:, sold_at:)
      sale = Sale.create!(
        location: location,
        sale_datetime: sold_at,
        customer_type: :staff,
        total_amount: 550,
        final_amount: 550,
        employee: employees(:verified_employee),
        status: :completed
      )
      sale.items.create!(
        catalog: catalogs(:daily_bento_a),
        catalog_price: catalog_prices(:daily_bento_a_regular),
        quantity: 1,
        unit_price: 550,
        sold_at: sold_at
      )
    end
  end
end
