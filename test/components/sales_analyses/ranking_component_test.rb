# frozen_string_literal: true

require "test_helper"

class SalesAnalyses::RankingComponentTest < ViewComponent::TestCase
  test "関係者・一般それぞれのランキング金額を通貨表記で表示し、負値はマイナス記号が通貨記号の前に付く" do
    result = render_ranking(staff_amount: 88_000, citizen_amount: 12_345)

    assert_equal [ "¥88,000", "¥12,345" ], ranking_amounts(result)

    result = render_ranking(staff_amount: -500, citizen_amount: -500)

    assert_equal [ "-¥500", "-¥500" ], ranking_amounts(result)
  end

  private

  def render_ranking(staff_amount:, citizen_amount:)
    render_inline(SalesAnalyses::Ranking::Component.new(data: {
      staff: [ { catalog_name: "日替わり弁当A", quantity: 10, amount: staff_amount } ],
      citizen: [ { catalog_name: "日替わり弁当B", quantity: 5, amount: citizen_amount } ]
    }))
  end

  def ranking_amounts(result)
    result.css("td.text-xs").map(&:text)
  end
end
