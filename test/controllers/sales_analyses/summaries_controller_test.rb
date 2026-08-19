# frozen_string_literal: true

require "test_helper"

module SalesAnalyses
  class SummariesControllerTest < ActionDispatch::IntegrationTest
    include SaleTestHelper

    fixtures :employees, :locations, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      login_as_employee(:verified_employee)
    end

    test "認証済みユーザーが summary にアクセスできる" do
      get sales_analyses_summary_path(location_id: locations(:city_hall).id, period: 30)

      assert_response :success
    end

    # 20 日前の販売は過去30日には入り、過去7日には入らない。フォールバック先が
    # 30 であることと、集計期間が実際にクエリへ効いていることを同時に見る
    test "対応していない集計期間を指定すると過去30日として扱われる" do
      location = Location.create!(name: "集計期間フォールバック検証販売先", status: :active)
      older = create_sale(location: location, customer_type: :staff, sale_datetime: 20.days.ago)
      recent = create_sale(location: location, customer_type: :staff, sale_datetime: 1.day.ago)
      create_sale_item(sale: older, quantity: 1)
      create_sale_item(sale: recent, quantity: 1)

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
  end
end
