require "test_helper"

module Sales
  class HistoryCalendarTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items

    setup do
      @location = locations(:city_hall)
      @calendar = Sales::HistoryCalendar.new(
        location: @location,
        month: Date.current
      )
    end

    # --- daily_totals ---

    test "日別売上合計は対象月の各日の売上金額をハッシュで返す" do
      result = @calendar.daily_totals

      assert result.is_a?(Hash)
      result.each_key { |date| assert_kind_of Date, date }
      assert result.values.all? { |v| v.is_a?(Numeric) && v > 0 }
    end

    test "日別売上合計は取消済みの販売を含まない" do
      result = @calendar.daily_totals
      total = result.values.sum

      # total には analysis_voided の final_amount が含まれないことを検証
      voided_date = 2.days.ago.to_date
      all_sales_on_voided_date = Sale.at_location(@location)
                                     .in_period(voided_date.beginning_of_day, voided_date.end_of_day)

      completed_amount = all_sales_on_voided_date.completed.sum(:final_amount)
      voided_amount = all_sales_on_voided_date.voided.sum(:final_amount)

      assert voided_amount > 0, "テストデータに取消済み販売が存在するはず"
      assert_equal completed_amount, result[voided_date] || 0
    end

    # --- monthly_summary ---

    test "月間サマリーは販売日数・総売上・1日平均・最高日を返す" do
      result = @calendar.monthly_summary

      assert result[:business_days] > 0
      assert result[:total_amount] > 0
      assert result[:daily_average] > 0
      assert_not_nil result[:best_day]
      assert result[:best_day][:amount] >= result[:daily_average]
    end

    test "月間サマリーの1日平均は合計を営業日数で割った値" do
      result = @calendar.monthly_summary

      expected_avg = result[:total_amount] / result[:business_days]
      assert_equal expected_avg, result[:daily_average]
    end

    # --- daily_breakdown ---

    test "日別内訳は指定日の商品別販売数量を返す" do
      target_date = 1.day.ago.to_date
      result = @calendar.daily_breakdown(target_date)

      assert result.is_a?(Array)
      assert result.length > 0

      entry = result.first
      assert entry.key?(:catalog_name)
      assert entry.key?(:staff_quantity)
      assert entry.key?(:citizen_quantity)
      assert entry.key?(:total_quantity)
    end

    test "日別内訳は販売数量の降順でソートされる" do
      target_date = 1.day.ago.to_date
      result = @calendar.daily_breakdown(target_date)

      totals = result.map { |r| r[:total_quantity] }
      assert_equal totals.sort.reverse, totals
    end

    test "販売がない日の内訳は空配列を返す" do
      result = @calendar.daily_breakdown(Date.new(2020, 1, 1))

      assert_equal [], result
    end
  end
end
