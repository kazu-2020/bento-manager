# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    class SalesHistoryControllerTest < ActionDispatch::IntegrationTest
      include QueryCountHelper

      fixtures :employees, :locations, :catalogs, :catalog_prices,
               :sales, :sale_items, :coupons, :discounts, :sale_discounts

      setup do
        @location = locations(:city_hall)
        login_as_employee(:verified_employee)
      end

      # POS のこの画面は弁当販売履歴とは別のものを指すため、名前を揃えてはいけない
      test "認証済みユーザーが当日の販売履歴にアクセスできる" do
        get pos_location_sales_history_index_path(@location)

        assert_response :success
        assert_select "title", "販売履歴"
      end

      test "未認証ユーザーはログインページにリダイレクトされる" do
        reset!
        get pos_location_sales_history_index_path(@location)

        assert_redirected_to "/employee/login"
      end

      test "停止中の拠点では販売履歴が 404 になる" do
        get pos_location_sales_history_index_path(locations(:prefectural_office))

        assert_response :not_found
      end

      test "販売履歴は販売が増えても問い合わせ本数が増えない" do
        another_sale = -> do
          sale = Sale.create!(
            location: @location,
            sale_datetime: Time.current,
            customer_type: :citizen,
            total_amount: 600,
            final_amount: 500,
            employee: employees(:owner_employee),
            status: :completed
          )
          SaleItem.create!(
            sale: sale,
            catalog: catalogs(:salad),
            catalog_price: catalog_prices(:salad_regular),
            quantity: 1,
            unit_price: 250,
            sold_at: sale.sale_datetime
          )
          SaleDiscount.create!(
            sale: sale,
            discount: discounts(:hundred_yen_discount),
            discount_amount: 100,
            quantity: 1
          )
        end

        assert_queries_unaffected_by(another_sale, "担当者と割引の読み込みが販売ごとに走っている") do
          get pos_location_sales_history_index_path(@location)
        end
      end

      test "日次サマリーの売上合計はクーポン割引前の金額の合算になる" do
        # completed_sale fixture: 今日の販売、total_amount=550, final_amount=500（50円クーポン適用）
        get pos_location_sales_history_index_path(@location)

        summary = @controller.view_assigns["daily_summary"]

        assert_equal 1, summary[:total_count]
        assert_equal 550, summary[:total_amount], "クーポン割引前金額（total_amount）を合算するべき"
      end
    end
  end
end
