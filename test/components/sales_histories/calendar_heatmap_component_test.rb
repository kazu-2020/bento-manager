# frozen_string_literal: true

require "test_helper"

class SalesHistories::CalendarHeatmapComponentTest < ViewComponent::TestCase
  setup do
    @location = Location.create!(name: "ヒートマップテスト販売先", status: :active)
  end

  test "マスには弁当の販売数を個数で表示する" do
    result = render_heatmap(
      quantities: { date(3) => 3, date(4) => 24 },
      rates: { date(3) => 0.6, date(4) => 0.9 }
    )

    assert_equal [ "3個", "24個" ], cell_quantities(result)
  end

  # 個数で塗ると月ごとに基準が動き、月をまたいだ比較ができない
  test "マスの濃淡は販売個数ではなく消化率で決まる" do
    result = render_heatmap(
      quantities: { date(3) => 20, date(4) => 20, date(5) => 5 },
      rates: { date(3) => 0.4, date(4) => 0.9, date(5) => 0.9 }
    )

    poorly_sold, well_sold, few_but_well_sold = cell_classes(result)

    assert_not_equal poorly_sold, well_sold, "同じ 20 個でも消化率が違えば濃さが違う"
    assert_equal well_sold, few_but_well_sold, "個数が違っても消化率が同じなら濃さは同じ"
  end

  # 消化率 100% は売り切ったことではなく、買いに来た客を逃した可能性のある日である。
  # 濃淡だけでは「最もよく売れた日」としか読めない
  test "残数が0だった日は濃淡とは別の印で見分けられる" do
    result = render_heatmap(
      quantities: { date(3) => 20, date(4) => 20 },
      rates: { date(3) => 1.0, date(4) => 0.9 }
    )

    sold_out_cell, remaining_cell = result.css("a")

    assert_predicate sold_out_cell.css("span.bg-warning"), :present?
    assert_empty remaining_cell.css("span.bg-warning")
  end

  # 弁当を 1 個も積まなかった日は消化率の分母が 0 で、率そのものが存在しない
  test "弁当を積まなかった日は色をつけない" do
    result = render_heatmap(
      quantities: { date(3) => 0, date(4) => 5 },
      rates: { date(4) => 1.0 }
    )

    not_loaded_cell, = result.css("a")

    assert_includes not_loaded_cell["class"], "bg-base-200"
    assert_empty not_loaded_cell.css("span.bg-warning"), "積まなかった日を残数 0 の日と混同しない"
  end

  # サラダしか売れなかった日。休日と区別しつつ、売れた日と同じ色では塗らない
  test "弁当が0個の日はマスを出すが色をつけない" do
    result = render_heatmap(
      quantities: { date(3) => 0, date(4) => 5 },
      rates: { date(3) => 0.0, date(4) => 0.5 }
    )

    assert_equal [ "0個", "5個" ], cell_quantities(result)
    assert_includes result.css("a").first["class"], "bg-base-200"
  end

  test "販売のなかった日は休みとして描く" do
    result = render_heatmap(quantities: { date(3) => 5 }, rates: { date(3) => 0.5 })

    assert_equal 1, result.css("a").size
    assert_includes result.to_html, "休"
  end

  private

  def date(day)
    Date.new(2026, 8, day)
  end

  def render_heatmap(quantities:, rates:)
    render_inline(SalesHistories::CalendarHeatmap::Component.new(
      month: Date.new(2026, 8, 1),
      daily_quantities: quantities,
      sell_through_rates: rates,
      location: @location
    ))
  end

  def cell_quantities(result)
    result.css("a div.opacity-80").map(&:text)
  end

  def cell_classes(result)
    result.css("a").map { |cell| cell["class"] }
  end
end
