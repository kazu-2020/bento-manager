# frozen_string_literal: true

require "test_helper"

class SalesHistories::DailySummaryComponentTest < ViewComponent::TestCase
  setup do
    @location = Location.create!(name: "日次サマリテスト販売先", status: :active)
  end

  test "弁当の販売数と取引件数をそれぞれの単位で並べる" do
    result = render_inline(SalesHistories::DailySummary::Component.new(
      total_quantity: 27, total_transactions: 3, location: @location
    ))

    assert_equal [ "27個", "3件", @location.name ], result.css("p.text-2xl").map(&:text)
  end
end
