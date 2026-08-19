# frozen_string_literal: true

require "test_helper"

class SalesAnalyses::FilterBarComponentTest < ViewComponent::TestCase
  setup do
    @city_hall = Location.create!(name: "分析フィルタテスト市役所", status: :active)
    @prefectural_office = Location.create!(name: "分析フィルタテスト県庁", status: :active)
  end

  test "販売先を切り替えても、表示中の集計期間は保たれる" do
    result = render_inline(SalesAnalyses::FilterBar::Component.new(
      location: @prefectural_office,
      period: 90,
      locations: [ @city_hall, @prefectural_office ]
    ))

    assert_equal [
      "/sales_analyses?location_id=#{@city_hall.id}&period=90",
      "/sales_analyses?location_id=#{@prefectural_office.id}&period=90"
    ], result.css("option").map { |o| o["value"] }

    assert_equal [ @prefectural_office.name ],
                 result.css("option[selected]").map { |o| o.text.strip }
  end
end
