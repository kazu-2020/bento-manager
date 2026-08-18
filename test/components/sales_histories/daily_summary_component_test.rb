# frozen_string_literal: true

require "test_helper"

class SalesHistories::DailySummaryComponentTest < ViewComponent::TestCase
  setup do
    @location = Location.create!(name: "日次サマリテスト販売先", status: :active)
  end

  test "売上合計を通貨表記で表示し、負値はマイナス記号が通貨記号の前に付く" do
    assert_equal "¥1,234,567", rendered_total(1_234_567)
    assert_equal "-¥500", rendered_total(-500)
  end

  private

  def rendered_total(total_amount)
    result = render_inline(SalesHistories::DailySummary::Component.new(
      total_amount: total_amount, total_transactions: 3, location: @location
    ))
    result.css("p.text-2xl").first.text
  end
end
