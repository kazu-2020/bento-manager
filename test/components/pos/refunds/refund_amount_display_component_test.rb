# frozen_string_literal: true

require "test_helper"

class Pos::Refunds::RefundAmountDisplayComponentTest < ViewComponent::TestCase
  include GhostFormSubmissionHelper
  include RefundParamsHelper
  include SaleRecordingHelper

  fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules,
           :daily_inventories, :coupons, :discounts

  setup do
    @location = locations(:city_hall)
    @employee = employees(:verified_employee)
    @catalog_bento_a = catalogs(:daily_bento_a)
    @discount = discounts(:fifty_yen_discount)
  end

  def submission_form
    ::Refunds::RefundForm
  end

  # 案内が出ないと、客に返すべきクーポンが手元に残る
  test "クーポンだけ減らした差額精算では、減らした枚数が返却するクーポンとして案内される" do
    sale = record_sale(
      [ { catalog: @catalog_bento_a, quantity: 2 } ],
      discount_quantities: { @discount.id => 2 }
    )
    form = submission_form.new(
      sale: sale,
      location: @location,
      submitted: submission(
        refund_quantity_params(corrected: { @catalog_bento_a => 2 }, coupon: { @discount => 1 })
      )
    )

    result = render_inline(Pos::Refunds::RefundAmountDisplay::Component.new(form: form))

    assert_includes result.text, @discount.name
    assert_includes result.text, "x1"
  end
end
