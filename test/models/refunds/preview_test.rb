require "test_helper"

module Refunds
  class PreviewTest < ActiveSupport::TestCase
    include SaleRecordingHelper

    fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules,
             :daily_inventories, :coupons, :discounts

    setup do
      @location = locations(:city_hall)
      @employee = employees(:verified_employee)
      @catalog_bento_a = catalogs(:daily_bento_a)
      @catalog_salad = catalogs(:salad)
    end

    test "修正カートに手が入っていない間は、修正後の金額も差額も0になる" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      preview = Preview.new(
        sale: sale,
        items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: {},
        changed: false
      )

      assert_equal 0, preview.final_total
      assert_empty preview.items_with_prices
      assert_empty preview.discount_details
      assert_equal 0, preview.adjustment_amount
      assert_equal :even_exchange, preview.adjustment_type
    end

    test "商品を足すと、差額は追加請求になる" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      preview = Preview.new(
        sale: sale,
        items: [
          { catalog: @catalog_bento_a, quantity: 1 },
          { catalog: @catalog_salad, quantity: 1 }
        ],
        discount_quantities: {},
        changed: true
      )

      # 弁当A(550) + サラダ(セット価格150) = 700円。差額: 550 - 700 = -150
      assert_equal 700, preview.final_total
      assert_equal(-150, preview.adjustment_amount)
      assert_equal :additional_charge, preview.adjustment_type
    end

    test "商品を減らすと、差額は返金になる" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 2 } ])

      preview = Preview.new(
        sale: sale,
        items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: {},
        changed: true
      )

      assert_equal 550, preview.final_total
      assert_equal 550, preview.adjustment_amount
      assert_equal :refund, preview.adjustment_type
    end

    # 価格が引けないまま金額を出すと、根拠の無い差額を客に提示することになる。
    # 修正後の商品が無いときと同じ扱いに倒し、全額返金として見せる
    test "修正後の商品に価格が設定されていないと、修正後の金額は0になりクーポンは返却として並ぶ" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: { discount.id => 1 }
      )
      priceless = Catalog.create!(name: "価格未設定弁当", kana: "カカクミセッテイベントウ", category: :bento)

      preview = Preview.new(
        sale: sale,
        items: [ { catalog: priceless, quantity: 1 } ],
        discount_quantities: {},
        changed: true
      )

      assert_equal 0, preview.final_total
      assert_empty preview.items_with_prices

      returned = preview.discount_details.find { |d| d[:discount_id] == discount.id }

      assert_equal 1, returned[:requested_quantity]
    end

    test "修正後の商品が無いと、修正後の金額は0になり元の販売のクーポンが返却として並ぶ" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: { discount.id => 1 }
      )

      preview = Preview.new(sale: sale, items: [], discount_quantities: {}, changed: true)

      assert_equal 0, preview.final_total
      assert_empty preview.items_with_prices

      returned = preview.discount_details.find { |d| d[:discount_id] == discount.id }

      assert_equal 0, returned[:quantity]
      assert_equal 1, returned[:requested_quantity]

      # 元の販売はクーポン1枚を引いた 500 円。全額が返金になる
      assert_equal 500, preview.adjustment_amount
      assert_equal :refund, preview.adjustment_type
    end
  end
end
