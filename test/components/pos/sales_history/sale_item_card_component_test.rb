# frozen_string_literal: true

require "test_helper"

class Pos::SalesHistory::SaleItemCardComponentTest < ViewComponent::TestCase
  include SaleTestHelper

  fixtures :employees

  setup do
    @location = Location.create!(name: "販売履歴カードテスト販売先", status: :active)
  end

  # 販売履歴が当日分しか出さないことに寄りかかると、別の画面がこのカードを
  # 使った途端、押しても差し戻されるだけのボタンが並ぶ
  test "差額精算ボタンは、当日のまだ取り消されていない販売にだけ出る" do
    refundable_sale = create_sale(location: @location, customer_type: :staff, sale_datetime: Time.current)
    yesterday_sale = create_sale(location: @location, customer_type: :staff, sale_datetime: 1.day.ago)
    voided_sale = create_sale(
      location: @location, customer_type: :staff, sale_datetime: Time.current,
      status: :voided, voided_at: Time.current, voided_by_employee: employees(:verified_employee)
    )

    assert_includes render_card(refundable_sale).to_html, "差額精算"
    assert_not_includes render_card(yesterday_sale).to_html, "差額精算"
    assert_not_includes render_card(voided_sale).to_html, "差額精算"
  end

  private

  # @param sale [Sale] カードに描く販売
  # @return [Nokogiri::HTML::DocumentFragment]
  def render_card(sale)
    render_inline(Pos::SalesHistory::SaleItemCard::Component.new(sale: sale, location: @location))
  end
end
