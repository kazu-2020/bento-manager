# frozen_string_literal: true

require "test_helper"

class SalesAnalyses::SummaryCardsComponentTest < ViewComponent::TestCase
  # 母が知りたいのは次に何個積むかであって金額ではない。カードに添えるのは構成比だけで、
  # 総販売数のカードには添え書き自体が無い（キャプションが 2 つしか無いことがその表明）
  test "サマリーは総販売数・関係者・一般の販売数を並べ、関係者と一般には構成比だけを添える" do
    result = render_cards

    assert_equal [ "弁当の総販売数", "関係者（職員）", "一般" ], result.css(".card-body p:first-child").map(&:text)
    assert_equal [ "20個", "12個", "8個" ], result.css(".card-body p:nth-child(2)").map(&:text)
    assert_equal [ "60%", "40%" ], card_captions(result)

    result = render_cards(staff_quantity: 0, citizen_quantity: 0)

    assert_equal [ "0%", "0%" ], card_captions(result)
  end

  private

  def render_cards(staff_quantity: 12, citizen_quantity: 8)
    render_inline(SalesAnalyses::SummaryCards::Component.new(quantities: {
      staff: staff_quantity,
      citizen: citizen_quantity
    }))
  end

  def card_captions(result)
    result.css("p.text-xs.text-base-content\\/50").map { |node| node.text.squish }
  end
end
