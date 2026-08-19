# frozen_string_literal: true

require "test_helper"

class SalesAnalyses::CrossTableComponentTest < ViewComponent::TestCase
  test "クロス集計は表題と、商品・合計・構成比・関係者比率の列見出しを表示する" do
    result = render_inline(SalesAnalyses::CrossTable::Component.new(data: [
      { catalog_name: "日替わり弁当A", total_quantity: 10, staff_quantity: 7, citizen_quantity: 3 }
    ]))

    assert_equal "弁当 × 顧客タイプ クロス集計", result.css("h3").text
    assert_equal [ "商品", "合計", "構成比", "関係者比率" ], result.css("th").map { |th| th.children.first.text.squish }
    assert_equal [ "関係者", "一般" ], result.css("th span").reject { |span| span.text == "■" }.map(&:text)
  end

  test "対象期間に販売がなければクロス集計はデータなしと伝える" do
    result = render_inline(SalesAnalyses::CrossTable::Component.new(data: []))

    assert_equal "データがありません", result.at_css(".card-body p").text
  end
end
