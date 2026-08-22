require "test_helper"

module Sales
  class AnalysisSummaryTest < ActiveSupport::TestCase
    include SaleTestHelper

    fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      @location = locations(:city_hall)
      @summary = Sales::AnalysisSummary.new(
        location: @location,
        period: Sales::AnalysisPeriod.new(days: 7)
      )
    end

    # --- summary_by_customer_type ---

    test "顧客タイプ別サマリーは職員と一般の販売個数だけを集計する" do
      result = @summary.summary_by_customer_type

      assert_equal %i[staff citizen], result.keys
      assert_operator result[:staff], :>, 0
      assert_operator result[:citizen], :>, 0
    end

    # 集計を検証するので対象は自分で作る（.claude/rules/testing.md §5）。加えて
    # フィクスチャの日時は読み込み時刻、集計期間は実行時刻の Date.current で
    # 決まるため、共有フィクスチャを数えると 0 時をまたいだ瞬間だけ窓が 1 日ずれる
    test "顧客タイプ別サマリーは取消済みの販売を含まない" do
      location = Location.create!(name: "集計テスト販売先", status: :active)
      summary = Sales::AnalysisSummary.new(location:, period: Sales::AnalysisPeriod.new(days: 7))

      create_sale_item(
        sale: create_sale(location:, customer_type: :staff, sale_datetime: 3.days.ago),
        quantity: 1
      )
      create_sale_item(
        sale: create_sale(
          location:,
          customer_type: :staff,
          sale_datetime: 3.days.ago,
          status: :voided,
          voided_at: 3.days.ago,
          voided_by_employee: employees(:owner_employee)
        ),
        quantity: 1
      )

      assert_equal 1, summary.summary_by_customer_type[:staff]
    end

    # 当日の販売は差額精算で変わりうるため、混ぜると同じ期間の数字が見るたびに動く。
    # 集計期間が当日を除くだけでなく、売上分析そのものが当日を含んではならない
    test "顧客タイプ別サマリーは当日の販売を含まない" do
      before = @summary.summary_by_customer_type

      today_sale = create_sale(location: @location, customer_type: :staff, sale_datetime: Time.current)
      create_sale_item(sale: today_sale, quantity: 1)

      assert_equal before, @summary.summary_by_customer_type
    end

    test "顧客タイプ別サマリーは他の出店先の販売を含まない" do
      result = @summary.summary_by_customer_type

      # analysis_pref_1 (県庁, staff) は含まれない
      # 市役所の staff 個数のみ
      staff_quantity = result[:staff]

      pref_summary = Sales::AnalysisSummary.new(
        location: locations(:prefectural_office),
        period: Sales::AnalysisPeriod.new(days: 7)
      )
      pref_result = pref_summary.summary_by_customer_type

      assert_not_equal staff_quantity, pref_result[:staff]
    end

    # --- 集計対象 ---

    # 3 つの集計が違う母集合を数えると、サマリーの「総販売数」とクロス集計表の
    # 合計が食い違う。#384 はサマリーだけがサイドメニューを含んでいた不具合
    test "売上分析はサイドメニューを含まず、どの集計も同じ弁当の数を数える" do
      location = Location.create!(name: "集計対象テスト販売先", status: :active)
      summary = Sales::AnalysisSummary.new(location:, period: Sales::AnalysisPeriod.new(days: 7))
      sale = create_sale(location:, customer_type: :staff, sale_datetime: 3.days.ago)

      create_sale_item(sale:, quantity: 1)
      create_sale_item(sale:, quantity: 2, catalog_price: catalog_prices(:salad_regular))

      assert_equal 1, summary.summary_by_customer_type[:staff]
      assert_equal [ catalogs(:daily_bento_a).name ], summary.ranking(limit: 10)[:staff].map { |e| e[:catalog_name] }
      assert_equal [ catalogs(:daily_bento_a).name ], summary.cross_table.map { |r| r[:catalog_name] }
      assert_equal(
        summary.summary_by_customer_type.values.sum,
        summary.cross_table.sum { |r| r[:total_quantity] }
      )
    end

    # --- ranking ---

    test "ランキングは顧客タイプ別に販売数量上位の商品を返す" do
      result = @summary.ranking(limit: 5)

      assert result.key?(:staff)
      assert result.key?(:citizen)
      assert_operator result[:staff].length, :<=, 5
      assert_operator result[:citizen].length, :<=, 5

      # 職員: 弁当A が最も多い（staff_1, staff_3, staff_4 = 3個。弁当B は staff_2, staff_5 = 2個）
      top_staff = result[:staff].first

      assert_equal catalogs(:daily_bento_a).name, top_staff[:catalog_name]
    end

    test "ランキングの各行は弁当名と販売個数だけを持つ" do
      result = @summary.ranking(limit: 5)
      entry = result[:staff].first

      assert_equal %i[catalog_name quantity], entry.keys
    end

    # --- cross_table ---

    test "クロス集計は商品ごとに職員と一般の販売数量を並べる" do
      result = @summary.cross_table

      assert_kind_of Array, result

      bento_a = result.find { |r| r[:catalog_name] == catalogs(:daily_bento_a).name }

      assert_not_nil bento_a
      assert_operator bento_a[:staff_quantity], :>, 0
      assert_operator bento_a[:citizen_quantity], :>, 0
      assert_equal bento_a[:staff_quantity] + bento_a[:citizen_quantity], bento_a[:total_quantity]
    end

    test "クロス集計は合計数量の降順でソートされる" do
      result = @summary.cross_table

      totals = result.map { |r| r[:total_quantity] }

      assert_equal totals.sort.reverse, totals
    end
  end
end
