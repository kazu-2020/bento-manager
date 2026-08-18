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
      assert_empty preview.returned_discounts
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
      assert_equal [ { discount_id: discount.id, discount_name: discount.name, quantity: 1 } ],
                   preview.returned_discounts
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
      assert_equal [ { discount_id: discount.id, discount_name: discount.name, quantity: 1 } ],
                   preview.returned_discounts

      # 元の販売はクーポン1枚を引いた 500 円。全額が返金になる
      assert_equal 500, preview.adjustment_amount
      assert_equal :refund, preview.adjustment_type
    end

    # 商品はそのままでクーポンだけ減らす経路。減った枚数は客の手元に戻す
    test "クーポンを減らすと、減った分が返却するクーポンになる" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 2 }
      )

      reduced = preview_for(sale, discount_quantities: { discount.id => 1 })

      assert_equal [ { discount_id: discount.id, discount_name: discount.name, quantity: 1 } ],
                   reduced.returned_discounts
      # 1100 - 50 = 1050。元の販売(1000円)との差額は追加請求 50 円
      assert_equal(-50, reduced.adjustment_amount)
      assert_equal :additional_charge, reduced.adjustment_type

      # 0 枚のクーポンは PriceCalculator に渡らず、修正後の結果には痕跡が残らない。
      # 元の販売と突き合わせないと返却が消える
      assert_equal [ { discount_id: discount.id, discount_name: discount.name, quantity: 2 } ],
                   preview_for(sale, discount_quantities: {}).returned_discounts
    end

    # 増やした分も、弁当の数を超えて要求した分も、元から客に渡っていない。
    # 返却として案内すると渡していないクーポンを渡すことになる
    test "クーポンを増やしても、弁当の数を超えて要求しても、返却するクーポンは出ない" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 1 }
      )

      assert_empty preview_for(sale, discount_quantities: { discount.id => 2 }).returned_discounts
      # 弁当 2 個に 3 枚を要求しても、適用されるのは 2 枚まで
      assert_empty preview_for(sale, discount_quantities: { discount.id => 3 }).returned_discounts
    end

    private

    # 商品はそのままでクーポンの枚数だけを差し替えた Preview
    def preview_for(sale, discount_quantities:)
      Preview.new(
        sale: sale,
        items: [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: discount_quantities,
        changed: true
      )
    end
  end
end
