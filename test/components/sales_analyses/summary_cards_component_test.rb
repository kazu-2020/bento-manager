# frozen_string_literal: true

require "test_helper"

class SalesAnalyses::SummaryCardsComponentTest < ViewComponent::TestCase
  test "総額・関係者・一般の3カードを通貨表記で表示し、負値はマイナス記号が通貨記号の前に付く" do
    result = render_cards(staff_amount: 800_000, citizen_amount: 434_567)

    assert_equal [ "¥1,234,567 相当", "50% ・ ¥800,000", "50% ・ ¥434,567" ], card_captions(result)

    result = render_cards(staff_amount: -500, citizen_amount: 0)

    assert_equal [ "-¥500 相当", "50% ・ -¥500", "50% ・ ¥0" ], card_captions(result)
  end

  test "サマリーは総販売数・関係者・一般の見出しと販売数の単位を表示する" do
    result = render_cards(staff_amount: 800_000, citizen_amount: 434_567)

    assert_equal [ "弁当の総販売数", "関係者（職員）", "一般" ], result.css(".card-body p:first-child").map(&:text)
    assert_equal [ "20個", "10個", "10個" ], result.css(".card-body p:nth-child(2)").map(&:text)
  end

  private

  def render_cards(staff_amount:, citizen_amount:)
    render_inline(SalesAnalyses::SummaryCards::Component.new(data: {
      staff: { quantity: 10, amount: staff_amount },
      citizen: { quantity: 10, amount: citizen_amount }
    }))
  end

  def card_captions(result)
    result.css("p.text-xs.text-base-content\\/50").map { |node| node.text.squish }
  end
end
