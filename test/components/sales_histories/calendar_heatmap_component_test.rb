# frozen_string_literal: true

require "test_helper"

class SalesHistories::CalendarHeatmapComponentTest < ViewComponent::TestCase
  setup do
    @location = Location.create!(name: "ヒートマップテスト販売先", status: :active)
  end

  test "1万円未満のマスは金額をそのまま、1万円以上は千円単位の k 表記で表示する" do
    result = render_heatmap(Date.new(2026, 8, 3) => 9_999, Date.new(2026, 8, 4) => 12_345)

    assert_equal [ "¥9,999", "¥12.3k" ], cell_amounts(result)
  end

  # k 表記は「千円単位」であることが読み取れるよう、千区切りを入れない
  test "k 表記には桁区切りを入れない" do
    result = render_heatmap(Date.new(2026, 8, 3) => 1_234_567)

    assert_equal [ "¥1234.6k" ], cell_amounts(result)
  end

  test "マイナスの金額はマイナス記号が通貨記号の前に付く" do
    result = render_heatmap(Date.new(2026, 8, 3) => -500, Date.new(2026, 8, 4) => -12_345)

    assert_equal [ "-¥500", "-¥12,345" ], cell_amounts(result)
  end

  private

  def render_heatmap(daily_totals)
    render_inline(SalesHistories::CalendarHeatmap::Component.new(
      month: Date.new(2026, 8, 1), daily_totals: daily_totals, location: @location
    ))
  end

  def cell_amounts(result)
    result.css("a div.opacity-80").map(&:text)
  end
end
