# frozen_string_literal: true

require "test_helper"

class SalesHistories::IndexPageComponentTest < ViewComponent::TestCase
  setup do
    @city_hall = Location.create!(name: "販売履歴テスト市役所", status: :active)
    @prefectural_office = Location.create!(name: "販売履歴テスト県庁", status: :active)
    @month = Date.new(2026, 3, 1)
  end

  test "販売先を切り替えても、表示中の月は保たれる" do
    result = render_inline(SalesHistories::IndexPage::Component.new(
      location: @prefectural_office,
      month: @month,
      calendar: Sales::HistoryCalendar.new(location: @prefectural_office, month: @month),
      locations: [ @city_hall, @prefectural_office ]
    ))

    assert_equal [
      "/sales_histories?location_id=#{@city_hall.id}&month=2026-03",
      "/sales_histories?location_id=#{@prefectural_office.id}&month=2026-03"
    ], result.css("option").map { |o| o["value"] }
  end
end
