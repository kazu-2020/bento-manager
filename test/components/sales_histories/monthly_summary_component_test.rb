# frozen_string_literal: true

require "test_helper"

class SalesHistories::MonthlySummaryComponentTest < ViewComponent::TestCase
  test "月合計・1日平均・最高日の3タイルを弁当の個数で表示する" do
    result = render_summary(total_quantity: 482, daily_average: 24.1, best_day_quantity: 38)

    assert_equal [ "482個", "24.1個", "38個" ], tile_values(result)
    assert_includes result.to_html, "8/3"
  end

  # 24.0個 と出しても読み手の役に立たない
  test "1日平均が割り切れる月は小数を出さない" do
    result = render_summary(total_quantity: 480, daily_average: 24.0, best_day_quantity: 38)

    assert_equal [ "480個", "24個", "38個" ], tile_values(result)
  end

  test "最高日が無い月はプレースホルダを表示し日付ラベルを出さない" do
    result = render_inline(SalesHistories::MonthlySummary::Component.new(summary: {
      total_quantity: 0, daily_average: 0.0, best_day: nil
    }))

    assert_equal [ "0個", "0個", "-" ], tile_values(result)
    assert_empty result.css("p.text-\\[10px\\]")
  end

  private

  def render_summary(total_quantity:, daily_average:, best_day_quantity:)
    render_inline(SalesHistories::MonthlySummary::Component.new(summary: {
      total_quantity: total_quantity,
      daily_average: daily_average,
      best_day: { date: Date.new(2026, 8, 3), quantity: best_day_quantity }
    }))
  end

  def tile_values(result)
    result.css("p.text-2xl").map(&:text)
  end
end
