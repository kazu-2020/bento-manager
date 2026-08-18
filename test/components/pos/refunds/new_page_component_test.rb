# frozen_string_literal: true

require "test_helper"

class Pos::Refunds::NewPageComponentTest < ViewComponent::TestCase
  fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules,
           :daily_inventories, :coupons, :discounts

  setup do
    @location = locations(:city_hall)
    @employee = employees(:verified_employee)
    @catalog_bento_a = catalogs(:daily_bento_a)
  end

  # 中身の無いタブを並べると、開いても空のパネルが出るだけになる
  test "修正カートに弁当しか無い差額精算の画面では、サイドメニューのタブは並ばない" do
    sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])
    # 在庫を渡さないので修正カートの母集合は元の販売の商品だけになる。
    # 当日在庫のフィクスチャが増えてもタブの並びは動かない
    form = ::Refunds::RefundForm.new(sale: sale, location: @location)

    result = render_inline(
      Pos::Refunds::NewPage::Component.new(form: form, sale: sale, location: @location)
    )

    tab_labels = result.css('[role="tablist"] [role="tab"]').map(&:text)

    assert_equal [ "弁当", "クーポン" ], tab_labels
  end

  private

  def create_sale(items)
    Sales::Recorder.new.record(
      { location: @location, customer_type: :staff, employee: @employee },
      items
    )
  end
end
