require "test_helper"

module Sales
  class AnalysisSummaryTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      @location = locations(:city_hall)
      @summary = Sales::AnalysisSummary.new(
        location: @location,
        from: 8.days.ago.beginning_of_day,
        to: Time.current
      )
    end

    # --- summary_by_customer_type ---

    test "顧客タイプ別サマリーは職員と一般の販売数量・金額を集計する" do
      result = @summary.summary_by_customer_type

      assert result.key?(:staff)
      assert result.key?(:citizen)
      assert result[:staff][:quantity] > 0
      assert result[:citizen][:quantity] > 0
      assert result[:staff][:amount] > 0
      assert result[:citizen][:amount] > 0
    end

    test "顧客タイプ別サマリーは取消済みの販売を含まない" do
      result = @summary.summary_by_customer_type

      # 期間内(8日前〜現在)の市役所 completed staff sales の line_total 合計:
      # completed_sale(550), staff_1(550), staff_2(500), staff_3(550+150), staff_4(550), staff_5(500)
      # analysis_voided は voided なので除外
      # 金額 = 550+550+500+700+550+500 = 3350
      assert_equal 3350, result[:staff][:amount]
    end

    test "顧客タイプ別サマリーは他の出店先の販売を含まない" do
      result = @summary.summary_by_customer_type

      # analysis_pref_1 (県庁, staff) は含まれない
      # 市役所の staff 金額のみ
      staff_amount = result[:staff][:amount]

      pref_summary = Sales::AnalysisSummary.new(
        location: locations(:prefectural_office),
        from: 8.days.ago.beginning_of_day,
        to: Time.current
      )
      pref_result = pref_summary.summary_by_customer_type

      assert_not_equal staff_amount, pref_result[:staff][:amount]
    end

    # --- ranking ---

    test "ランキングは顧客タイプ別に販売数量上位の商品を返す" do
      result = @summary.ranking(limit: 5)

      assert result.key?(:staff)
      assert result.key?(:citizen)
      assert result[:staff].length <= 5
      assert result[:citizen].length <= 5

      # 職員: 弁当A が最も多い（staff_1, staff_3, staff_4 + completed_sale = 4個）
      top_staff = result[:staff].first
      assert_equal catalogs(:daily_bento_a).name, top_staff[:catalog_name]
    end

    test "ランキングはサイドメニューを含まない" do
      result = @summary.ranking(limit: 10)

      all_names = result[:staff].map { |e| e[:catalog_name] } + result[:citizen].map { |e| e[:catalog_name] }
      assert_not_includes all_names, catalogs(:salad).name
    end

    test "ランキングの各行は商品名・数量・金額を含む" do
      result = @summary.ranking(limit: 5)
      entry = result[:staff].first

      assert entry.key?(:catalog_name)
      assert entry.key?(:quantity)
      assert entry.key?(:amount)
    end

    # --- cross_table ---

    test "クロス集計は商品ごとに職員と一般の販売数量を並べる" do
      result = @summary.cross_table

      assert result.is_a?(Array)

      bento_a = result.find { |r| r[:catalog_name] == catalogs(:daily_bento_a).name }
      assert_not_nil bento_a
      assert bento_a[:staff_quantity] > 0
      assert bento_a[:citizen_quantity] > 0
      assert_equal bento_a[:staff_quantity] + bento_a[:citizen_quantity], bento_a[:total_quantity]
    end

    test "クロス集計はサイドメニューを含まない" do
      result = @summary.cross_table

      all_names = result.map { |r| r[:catalog_name] }
      assert_not_includes all_names, catalogs(:salad).name
    end

    test "クロス集計は合計数量の降順でソートされる" do
      result = @summary.cross_table

      totals = result.map { |r| r[:total_quantity] }
      assert_equal totals.sort.reverse, totals
    end
  end
end
