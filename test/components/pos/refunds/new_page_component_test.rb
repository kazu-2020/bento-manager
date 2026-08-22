# frozen_string_literal: true

require "test_helper"

class Pos::Refunds::NewPageComponentTest < ViewComponent::TestCase
  include SaleRecordingHelper
  include GhostFormCorrespondenceHelper

  fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules,
           :daily_inventories, :coupons, :discounts

  setup do
    @location = locations(:city_hall)
    @employee = employees(:verified_employee)
    @catalog_bento_a = catalogs(:daily_bento_a)
  end

  # 中身の無いタブを並べると、開いても空のパネルが出るだけになる
  test "修正カートに弁当しか無い差額精算の画面では、サイドメニューのタブは並ばない" do
    sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])
    # 在庫を渡さないので修正カートの母集合は元の販売の商品だけになる。
    # 当日在庫のフィクスチャが増えてもタブの並びは動かない
    form = ::Refunds::RefundForm.new(sale: sale, location: @location)

    result = render_inline(
      Pos::Refunds::NewPage::Component.new(form: form, sale: sale, location: @location)
    )

    tab_labels = result.css('[role="tablist"] [role="tab"]').map(&:text)

    assert_equal [ "弁当", "クーポン" ], tab_labels
  end

  # コントローラテストは ghost_refund[...] を手書きして POST するため、ブラウザが
  # 実際にそのキーを組み立てられるかは通らない。詳細は
  # test/support/ghost_form_correspondence_helper.rb を参照
  test "差額精算画面の入力は、すべて Ghost Form 側に ghost_ 付きの受け皿を持つ" do
    sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ],
                       discount_quantities: { discounts(:fifty_yen_discount).id => 1 })
    # 修正カートの母集合は「元の販売の商品 + 当日の在庫」。在庫を渡さないと
    # 母集合が元の販売の 1 品だけに痩せ、当日在庫だけに居る商品の入力名を検査できない
    form = ::Refunds::RefundForm.new(
      sale: sale,
      location: @location,
      inventories: @location.today_inventories.for_cart
    )

    result = render_inline(
      Pos::Refunds::NewPage::Component.new(form: form, sale: sale, location: @location)
    )

    # 修正カートの数量とクーポンの枚数の 2 系統が母集合に出ているはず。
    # 当日在庫は弁当A・弁当B・サラダ、有効なクーポンは 50 円・100 円の 2 種類
    assert_ghost_inputs_correspond(result, minimum: 5)
  end
end
