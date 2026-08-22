# frozen_string_literal: true

require "test_helper"

class SalesAnalyses::RankingComponentTest < ViewComponent::TestCase
  # 表題の「TopN」は取得件数がそのまま出る。5 を焼き付けていないことを見るため 3 で描画する。
  # 行に金額が無いことは、行が順位・弁当名・販売数の 3 セルで終わることで示す
  test "ランキングは見出しに取得件数を添え、順位・弁当名・販売数だけを並べる" do
    result = render_ranking(limit: 3)

    assert_equal [ "関係者 人気弁当 Top3", "一般 人気弁当 Top3" ], result.css("h3").map(&:text)
    assert_equal [ "商品", "販売数" ], result.css("table").first.css("th").map(&:text).drop(1)
    assert_equal [ "1", "日替わり弁当A", "10 個" ], result.css("tbody tr").first.css("td").map { |td| td.text.squish }
  end

  test "対象期間に販売がなければ関係者・一般とも表を出さずデータなしと伝える" do
    result = render_inline(SalesAnalyses::Ranking::Component.new(data: { staff: [], citizen: [] }, limit: 5))

    assert_equal [ "データがありません", "データがありません" ], result.css(".card-body p").map(&:text)
    assert_empty result.css("table")
  end

  private

  def render_ranking(limit:)
    render_inline(SalesAnalyses::Ranking::Component.new(data: {
      staff: [ { catalog_name: "日替わり弁当A", quantity: 10 } ],
      citizen: [ { catalog_name: "日替わり弁当B", quantity: 5 } ]
    }, limit: limit))
  end
end
