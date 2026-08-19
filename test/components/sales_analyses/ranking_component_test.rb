# frozen_string_literal: true

require "test_helper"

class SalesAnalyses::RankingComponentTest < ViewComponent::TestCase
  test "関係者・一般それぞれのランキング金額を通貨表記で表示し、負値はマイナス記号が通貨記号の前に付く" do
    result = render_ranking(staff_amount: 88_000, citizen_amount: 12_345)

    assert_equal [ "¥88,000", "¥12,345" ], ranking_amounts(result)

    result = render_ranking(staff_amount: -500, citizen_amount: -500)

    assert_equal [ "-¥500", "-¥500" ], ranking_amounts(result)
  end

  # 表題の「TopN」は取得件数がそのまま出る。5 を焼き付けていないことを見るため 3 で描画する
  test "ランキングは関係者・一般それぞれの見出しに取得件数を添え、列見出しと販売数の単位を表示する" do
    result = render_ranking(staff_amount: 88_000, citizen_amount: 12_345, limit: 3)

    assert_equal [ "関係者 人気弁当 Top3", "一般 人気弁当 Top3" ], result.css("h3").map(&:text)
    assert_equal [ "商品", "販売数", "金額" ], result.css("table").first.css("th").map(&:text).drop(1)
    assert_equal [ "10 個", "5 個" ], result.css("tbody td:nth-child(3)").map { |td| td.text.squish }
  end

  test "対象期間に販売がなければ関係者・一般とも表を出さずデータなしと伝える" do
    result = render_inline(SalesAnalyses::Ranking::Component.new(data: { staff: [], citizen: [] }, limit: 5))

    assert_equal [ "データがありません", "データがありません" ], result.css(".card-body p").map(&:text)
    assert_empty result.css("table")
  end

  private

  def render_ranking(staff_amount:, citizen_amount:, limit: 5)
    render_inline(SalesAnalyses::Ranking::Component.new(data: {
      staff: [ { catalog_name: "日替わり弁当A", quantity: 10, amount: staff_amount } ],
      citizen: [ { catalog_name: "日替わり弁当B", quantity: 5, amount: citizen_amount } ]
    }, limit: limit))
  end

  def ranking_amounts(result)
    result.css("td.text-xs").map(&:text)
  end
end
