# frozen_string_literal: true

require "test_helper"

class SalesHistories::DailyDetailPanelComponentTest < ViewComponent::TestCase
  setup do
    @location = Location.create!(name: "日次詳細テスト販売先", status: :active)
  end

  test "選択日の弁当の販売数と取引件数を表示する" do
    result = render_panel(
      breakdown: [
        { catalog_name: "日替わり弁当A", total_quantity: 3, staff_quantity: 2, citizen_quantity: 1 },
        { catalog_name: "日替わり弁当B", total_quantity: 1, staff_quantity: 0, citizen_quantity: 1 }
      ],
      transaction_count: 3
    )

    assert_equal [ "4個", "3件" ], result.css("p.text-xl").map(&:text)
  end

  # サラダしか売れなかった日。内訳は空でも取引はある
  test "弁当が売れなかった日は販売数0個と取引件数を並べる" do
    result = render_panel(breakdown: [], transaction_count: 2)

    assert_equal [ "0個", "2件" ], result.css("p.text-xl").map(&:text)
  end

  private

  def render_panel(breakdown:, transaction_count:)
    render_inline(SalesHistories::DailyDetailPanel::Component.new(
      date: Date.new(2026, 8, 3),
      location: @location,
      breakdown: breakdown,
      transaction_count: transaction_count
    ))
  end
end
