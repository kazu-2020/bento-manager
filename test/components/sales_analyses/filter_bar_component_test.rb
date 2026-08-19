# frozen_string_literal: true

require "test_helper"

class SalesAnalyses::FilterBarComponentTest < ViewComponent::TestCase
  setup do
    @city_hall = Location.new(id: 1, name: "市役所", status: :active)
    @prefectural_office = Location.new(id: 2, name: "県庁", status: :active)
  end

  test "販売先を切り替えても、表示中の集計期間は保たれる" do
    result = render_inline(SalesAnalyses::FilterBar::Component.new(
      location: @prefectural_office,
      period: Sales::AnalysisPeriod.new(days: 90),
      locations: [ @city_hall, @prefectural_office ]
    ))

    assert_equal [
      "/sales_analyses?days=90&location_id=#{@city_hall.id}",
      "/sales_analyses?days=90&location_id=#{@prefectural_office.id}"
    ], result.css("option").map { |o| o["value"] }
  end

  test "フィルターバーは見出しと集計期間、選べる集計日数のプリセットを表示する" do
    period = Sales::AnalysisPeriod.new(days: 7)

    result = render_inline(SalesAnalyses::FilterBar::Component.new(
      location: @city_hall,
      period: period,
      locations: [ @city_hall ]
    ))

    assert_equal "顧客タイプ別 商品分析", result.css("h2").text
    assert_equal "#{I18n.l(period.first_date)} 〜 #{I18n.l(period.last_date)}", result.at_css("h2 + p").text
    assert_equal [ "過去7日", "過去30日", "過去90日" ], result.css(".join a").map(&:text)
  end
end
