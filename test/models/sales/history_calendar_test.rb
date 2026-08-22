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
      sell(on: date(2), customer_type: :staff, quantity: 2)
      sell(on: date(2), customer_type: :citizen, quantity: 1, catalog_price: catalog_prices(:daily_bento_b_regular))

      # 3/5: サラダ x1 のみの 1 取引
      sell(on: date(5), customer_type: :citizen, quantity: 1, catalog_price: catalog_prices(:salad_regular))

      # 3/9: 弁当A x5（職員）。同じ日の取消済み 弁当A x3 は数えない
      sell(on: date(9), customer_type: :staff, quantity: 5)
      sell(on: date(9), customer_type: :staff, quantity: 3, status: :voided)

      # 3/9: 別の販売先の 弁当A x9
      sell(on: date(9), customer_type: :staff, quantity: 9, location: @other_location)
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
      calendar = Sales::HistoryCalendar.new(location: @location, month: MONTH.prev_month)

      assert_empty calendar.daily_quantities
    end

    # --- daily_sell_through ---

    test "消化率はその日に積んだ弁当のうち売れた割合になる" do
      # 3/2 は 3 個売れて残数 1。積んだのは 4 個
      stock(on: date(2), remaining: 1)
      # 3/5 はサラダしか売れていないが、弁当を 10 個積んである
      stock(on: date(5), remaining: 10)
      # 3/9 は 5 個売れて残数 0。積んだ分を売り切っている
      stock(on: date(9), remaining: 0)

      result = @calendar.daily_sell_through

      assert_in_delta(0.75, result[date(2)].rate)
      assert_in_delta(0.0, result[date(5)].rate)
      assert_in_delta(1.0, result[date(9)].rate)
      assert_predicate result[date(9)], :no_remaining_stock?
      assert_not_predicate result[date(2)], :no_remaining_stock?
    end

    test "弁当を1個も積まなかった日は消化率を持たない" do
      # 3/2 はサラダを積んだだけ、3/5 は弁当とサラダの両方。分母が 0 の日は率が定まらず、
      # 0% とも 100% とも言えない。サイドメニューは分母に入れない（ADR-0006）
      stock(on: date(2), catalog: catalogs(:salad), remaining: 6)
      stock(on: date(5), remaining: 10)
      stock(on: date(5), catalog: catalogs(:salad), remaining: 6)

      result = @calendar.daily_sell_through

      assert_not_includes result.keys, date(2)
      assert_in_delta(0.0, result[date(5)].rate)
    end

    test "積んでいない日の売れ方は組み立てられない" do
      # 率が NaN になり、色をつけないためのガードも残数 0 の判定もすべて素通りする。
      # 率が定まらないことは不在で表す（ADR-0008）という約束を型の側でも守る
      error = assert_raises(ArgumentError) do
        Sales::HistoryCalendar::DailySellThrough.new(loaded: 0, sold: 0)
      end

      assert_match(/積んだ総数/, error.message)
    end

    test "当日在庫の記録が残っていない日は消化率を持たない" do
      # 在庫の記録が無い日を「残数 0 で売り切った日」と読むと、客を逃した日として
      # 名指ししてしまう。積んだ数が分からない日は率も分からない
      assert_empty @calendar.daily_sell_through
    end

    test "消化率は取消済みの販売を分子にも分母にも入れない" do
      # 3/9 は確定 5 個・取消 3 個。取消で戻った在庫は残数 2 に含まれる
      stock(on: date(9), remaining: 2)

      assert_in_delta(5 / 7.0, @calendar.daily_sell_through[date(9)].rate)
    end

    test "消化率は他の販売先の在庫を含まない" do
      stock(on: date(9), remaining: 0)
      stock(on: date(9), remaining: 91, location: @other_location)

      assert_in_delta(1.0, @calendar.daily_sell_through[date(9)].rate)
      assert_in_delta(0.09, Sales::HistoryCalendar.new(location: @other_location, month: MONTH)
        .daily_sell_through[date(9)].rate)
    end

    # --- monthly_summary ---

    test "月間サマリーは販売日数・弁当の月合計・1日平均・最高日を返す" do
      result = @calendar.monthly_summary

      assert_equal 3, result[:business_days]
      assert_equal 8, result[:total_quantity]
      assert_in_delta(2.7, result[:daily_average])
      assert_equal({ date: date(9), quantity: 5 }, result[:best_day])
    end

    test "1日平均の分母にはサラダしか売れなかった日も入る" do
      # 8 個 ÷ 3 日 = 2.7。弁当が売れなかった日も店を開けた日である
      assert_in_delta(2.7, @calendar.monthly_summary[:daily_average])
    end

    test "1日平均は1個未満を切り捨てない" do
      # 積込数を決めるために見る数字なので、常に少なめに出る平均は積みすぎを招く
      assert_operator @calendar.monthly_summary[:daily_average], :>, 8 / 3
    end

    test "弁当が1個も売れなかった月は最高日を持たない" do
      month = MONTH.next_month
      sell(on: month.change(day: 3), customer_type: :citizen, quantity: 1,
           catalog_price: catalog_prices(:salad_regular))
      result = Sales::HistoryCalendar.new(location: @location, month: month).monthly_summary

      assert_equal 1, result[:business_days], "サラダが売れた日は販売日として数える"
      assert_equal 0, result[:total_quantity]
      assert_nil result[:best_day], "ヒートマップが色をつけない日を最高日として名指ししない"
    end

    test "販売が1件もない月の月間サマリーは0を返し最高日を持たない" do
      result = Sales::HistoryCalendar.new(location: @location, month: MONTH.prev_month).monthly_summary

      assert_equal 0, result[:business_days]
      assert_equal 0, result[:total_quantity]
      assert_in_delta(0.0, result[:daily_average])
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

    # その日の販売が終わった時点の在庫。積んだ総数は保存されないため、
    # テストも残数を置いて積んだ総数を復元させる
    def stock(on:, remaining:, catalog: catalogs(:daily_bento_a), location: @location)
      DailyInventory.create!(
        location: location,
        catalog: catalog,
        inventory_date: on,
        stock: remaining,
        reserved_stock: 0
      )
    end

    def sell(on:, customer_type:, quantity:, catalog_price: catalog_prices(:daily_bento_a_regular),
             status: :completed, location: @location)
      voided = status == :voided
      sale = create_sale(
        location: location,
        customer_type: customer_type,
        sale_datetime: on.in_time_zone.change(hour: 12),
        status: status,
        voided_at: voided ? on.in_time_zone.change(hour: 13) : nil,
        voided_by_employee: voided ? employees(:owner_employee) : nil
      )
      create_sale_item(sale: sale, quantity: quantity, catalog_price: catalog_price)
      sale
    end
  end
end
