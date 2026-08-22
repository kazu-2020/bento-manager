# frozen_string_literal: true

require "test_helper"

class SalesHistories::CalendarHeatmapComponentTest < ViewComponent::TestCase
  setup do
    @location = Location.create!(name: "ヒートマップテスト販売先", status: :active)
  end

  test "マスには弁当の販売数を個数で表示する" do
    result = render_heatmap(Date.new(2026, 8, 3) => 3, Date.new(2026, 8, 4) => 24)

    assert_equal [ "3個", "24個" ], cell_quantities(result)
  end

  # サラダしか売れなかった日。休日と区別しつつ、売れた日と同じ色では塗らない
  test "弁当が0個の日はマスを出すが色をつけない" do
    result = render_heatmap(Date.new(2026, 8, 3) => 0, Date.new(2026, 8, 4) => 5)

    assert_equal [ "0個", "5個" ], cell_quantities(result)
    assert_includes result.css("a").first["class"], "bg-base-200"
  end

  test "販売のなかった日は休みとして描く" do
    result = render_heatmap(Date.new(2026, 8, 3) => 5)

    assert_equal 1, result.css("a").size
    assert_includes result.to_html, "休"
  end

  private

  def render_heatmap(daily_quantities)
    render_inline(SalesHistories::CalendarHeatmap::Component.new(
      month: Date.new(2026, 8, 1), daily_quantities: daily_quantities, location: @location
    ))
  end

  def cell_quantities(result)
    result.css("a div.opacity-80").map(&:text)
  end
end
