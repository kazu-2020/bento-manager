# frozen_string_literal: true

require "test_helper"

class SalesHistories::DailyDetailPanelComponentTest < ViewComponent::TestCase
  setup do
    @location = Location.create!(name: "日次詳細テスト販売先", status: :active)
  end

  test "選択日の売上を通貨表記で表示し、負値はマイナス記号が通貨記号の前に付く" do
    assert_equal "¥1,234,567", rendered_total(1_234_567)
    assert_equal "-¥500", rendered_total(-500)
  end

  private

  def rendered_total(daily_total)
    result = render_inline(SalesHistories::DailyDetailPanel::Component.new(
      date: Date.new(2026, 8, 3),
      location: @location,
      breakdown: [ { catalog_name: "日替わり弁当A", total_quantity: 3, staff_quantity: 2, citizen_quantity: 1 } ],
      daily_total: daily_total
    ))
    result.css("p.text-xl").first.text
  end
end
