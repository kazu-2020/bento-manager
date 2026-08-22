require "test_helper"

module Sales
  class HistoryCalendarTest < ActiveSupport::TestCase
    include SaleTestHelper

    # 集計対象は自分で作る。共有フィクスチャを数えると他テストクラスの販売が混ざる
    fixtures :employees, :catalogs, :catalog_prices

    MONTH = Date.new(2026, 3, 1)

    setup do
      @location = Location.create!(name: "販売履歴集計テスト販売先", status: :active)
      @other_location = Location.create!(name: "販売履歴集計テスト別販売先", status: :active)
      @calendar = Sales::HistoryCalendar.new(location: @location, month: MONTH)

      # 3/2: 弁当A x2（職員）、弁当B x1（一般）の 2 取引
      sell(day: 2, customer_type: :staff, quantity: 2)
      sell(day: 2, customer_type: :citizen, quantity: 1, catalog_price: catalog_prices(:daily_bento_b_regular))

      # 3/5: サラダ x1 のみの 1 取引
      sell(day: 5, customer_type: :citizen, quantity: 1, catalog_price: catalog_prices(:salad_regular))

      # 3/9: 弁当A x5（職員）。同じ日の取消済み 弁当A x3 は数えない
      sell(day: 9, customer_type: :staff, quantity: 5)
      sell(day: 9, customer_type: :staff, quantity: 3, status: :voided)

      # 3/9: 別の販売先の 弁当A x9
      sell(day: 9, customer_type: :staff, quantity: 9, location: @other_location)
    end

    # --- daily_quantities ---

    test "日別販売数は販売のあった日ごとに弁当の個数を返す" do
      assert_equal(
        { date(2) => 3, date(5) => 0, date(9) => 5 },
        @calendar.daily_quantities
      )
    end

    test "サラダしか売れなかった日も販売日として残り、弁当は0個になる" do
      result = @calendar.daily_quantities

      assert_includes result.keys, date(5), "販売のあった日はヒートマップ上で休日と区別されるべき"
      assert_equal 0, result[date(5)]
    end

    test "日別販売数は他の販売先の弁当を含まない" do
      other = Sales::HistoryCalendar.new(location: @other_location, month: MONTH)

      assert_equal({ date(9) => 9 }, other.daily_quantities)
    end

    test "販売が1件もない月の日別販売数は空になる" do
      calendar = Sales::HistoryCalendar.new(location: @location, month: MONTH.next_month)

      assert_empty calendar.daily_quantities
    end

    # --- monthly_summary ---

    test "月間サマリーは販売日数・弁当の月合計・1日平均・最高日を返す" do
      result = @calendar.monthly_summary

      assert_equal 3, result[:business_days]
      assert_equal 8, result[:total_quantity]
      assert_equal 2, result[:daily_average]
      assert_equal({ date: date(9), quantity: 5 }, result[:best_day])
    end

    test "1日平均の分母にはサラダしか売れなかった日も入る" do
      # 8 個 ÷ 3 日。弁当が売れなかった日も店を開けた日である
      assert_equal 2, @calendar.monthly_summary[:daily_average]
    end

    test "販売が1件もない月の月間サマリーは0を返し最高日を持たない" do
      result = Sales::HistoryCalendar.new(location: @location, month: MONTH.next_month).monthly_summary

      assert_equal 0, result[:business_days]
      assert_equal 0, result[:total_quantity]
      assert_equal 0, result[:daily_average]
      assert_nil result[:best_day]
    end

    # --- daily_breakdown ---

    test "日別内訳は指定日の弁当を顧客タイプ別に並べる" do
      assert_equal [
        { catalog_name: "日替わり弁当A", staff_quantity: 2, citizen_quantity: 0, total_quantity: 2 },
        { catalog_name: "日替わり弁当B", staff_quantity: 0, citizen_quantity: 1, total_quantity: 1 }
      ], @calendar.daily_breakdown(date(2))
    end

    test "日別内訳はサラダを並べない" do
      assert_equal [], @calendar.daily_breakdown(date(5))
    end

    test "日別内訳は取消済みの販売を含まない" do
      assert_equal [
        { catalog_name: "日替わり弁当A", staff_quantity: 5, citizen_quantity: 0, total_quantity: 5 }
      ], @calendar.daily_breakdown(date(9))
    end

    test "販売がない日の内訳は空配列を返す" do
      assert_equal [], @calendar.daily_breakdown(date(3))
    end

    # --- bento_quantity ---

    test "指定日の弁当の個数はサラダを数えない" do
      assert_equal 3, @calendar.bento_quantity(date(2))
      assert_equal 0, @calendar.bento_quantity(date(5)), "サラダしか売れなかった日は0個"
    end

    test "指定日の弁当の個数は取消済みの販売を含まない" do
      assert_equal 5, @calendar.bento_quantity(date(9))
    end

    test "販売がない日の弁当の個数は0になる" do
      assert_equal 0, @calendar.bento_quantity(date(3))
    end

    # --- transaction_count ---

    test "取引件数は弁当で絞らず、その日の取引の数を返す" do
      assert_equal 2, @calendar.transaction_count(date(2))
      assert_equal 1, @calendar.transaction_count(date(5)), "サラダだけの取引も 1 件と数える"
    end

    test "取引件数は取消済みの販売を含まない" do
      assert_equal 1, @calendar.transaction_count(date(9))
    end

    private

    def date(day)
      Date.new(MONTH.year, MONTH.month, day)
    end

    def sell(day:, customer_type:, quantity:, catalog_price: catalog_prices(:daily_bento_a_regular),
             status: :completed, location: @location)
      voided = status == :voided
      sale = create_sale(
        location: location,
        customer_type: customer_type,
        sale_datetime: Time.zone.local(MONTH.year, MONTH.month, day, 12, 0),
        status: status,
        voided_at: voided ? Time.zone.local(MONTH.year, MONTH.month, day, 13, 0) : nil,
        voided_by_employee: voided ? employees(:owner_employee) : nil
      )
      create_sale_item(sale: sale, quantity: quantity, catalog_price: catalog_price)
      sale
    end
  end
end
