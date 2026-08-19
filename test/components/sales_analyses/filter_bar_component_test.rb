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
end
