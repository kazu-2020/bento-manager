# frozen_string_literal: true

require "test_helper"

class SalesHistories::MonthlySummaryComponentTest < ViewComponent::TestCase
  test "月合計・1日平均・最高日の3タイルを通貨表記で表示し、負値はマイナス記号が通貨記号の前に付く" do
    result = render_summary(total_amount: 1_234_567, daily_average: 39_824, best_day_amount: 88_000)

    assert_equal [ "¥1,234,567", "¥39,824", "¥88,000" ], tile_values(result)
    assert_includes result.to_html, "8/3"

    result = render_summary(total_amount: -500, daily_average: -16, best_day_amount: -500)

    assert_equal [ "-¥500", "-¥16", "-¥500" ], tile_values(result)
  end

  test "最高日が無い月はプレースホルダを表示し日付ラベルを出さない" do
    result = render_inline(SalesHistories::MonthlySummary::Component.new(summary: {
      total_amount: 0, daily_average: 0, best_day: nil
    }))

    assert_equal [ "¥0", "¥0", "-" ], tile_values(result)
    assert_empty result.css("p.text-\\[10px\\]")
  end

  private

  def render_summary(total_amount:, daily_average:, best_day_amount:)
    render_inline(SalesHistories::MonthlySummary::Component.new(summary: {
      total_amount: total_amount,
      daily_average: daily_average,
      best_day: { date: Date.new(2026, 8, 3), amount: best_day_amount }
    }))
  end

  def tile_values(result)
    result.css("p.text-2xl").map(&:text)
  end
end
