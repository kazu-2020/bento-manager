require "test_helper"

module Sales
  class PriceCalculatorTest < ActiveSupport::TestCase
    fixtures :catalogs, :catalog_prices, :catalog_pricing_rules, :discounts, :coupons

    # ===== 10.1 基本構造テスト =====

    test "responds to calculate instance method" do
      calculator = Sales::PriceCalculator.new([])
      assert_respond_to calculator, :calculate
    end

    test "calculate returns a hash with required keys" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_kind_of Hash, result
      assert result.key?(:items_with_prices)
      assert result.key?(:subtotal)
      assert result.key?(:discount_details)
      assert result.key?(:total_discount_amount)
      assert result.key?(:final_total)
    end

    test "calculate with empty cart returns zero totals" do
      result = Sales::PriceCalculator.new([]).calculate

      assert_equal [], result[:items_with_prices]
      assert_equal 0, result[:subtotal]
      assert_equal [], result[:discount_details]
      assert_equal 0, result[:total_discount_amount]
      assert_equal 0, result[:final_total]
    end

    # ===== 10.2 価格ルール適用テスト =====

    test "apply_pricing_rules returns items with regular price when no rule applies" do
      # 弁当単独の場合、通常価格
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).send(:apply_pricing_rules)

      assert_equal 1, result.length
      item = result.first
      assert_equal 550, item[:unit_price]
      assert_equal catalog_prices(:daily_bento_a_regular).id, item[:catalog_price_id]
    end

    test "apply_pricing_rules applies bundle price when rule matches" do
      # 弁当1個 + サラダ1個 → サラダはセット価格 150円
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).send(:apply_pricing_rules)

      bento_item = result.find { |i| i[:catalog].bento? }
      salad_item = result.find { |i| i[:catalog].side_menu? }

      assert_equal 550, bento_item[:unit_price]
      assert_equal 150, salad_item[:unit_price]
      assert_equal catalog_prices(:salad_bundle).id, salad_item[:catalog_price_id]
    end

    test "apply_pricing_rules applies bundle price up to max_per_trigger" do
      # 弁当1個 + サラダ3個 → サラダ1個はセット価格、残り2個は通常価格
      # max_per_trigger: 1 なので、弁当1個につきサラダ1個まで
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 3 }
      ]

      result = Sales::PriceCalculator.new(cart_items).send(:apply_pricing_rules)

      salad_items = result.select { |i| i[:catalog].side_menu? }
      # 数量3を分割して返す: 1個@150 + 2個@250
      bundle_item = salad_items.find { |i| i[:unit_price] == 150 }
      regular_item = salad_items.find { |i| i[:unit_price] == 250 }

      assert_not_nil bundle_item
      assert_equal 1, bundle_item[:quantity]

      assert_not_nil regular_item
      assert_equal 2, regular_item[:quantity]
    end

    test "apply_pricing_rules applies bundle price proportionally to bentos" do
      # 弁当3個 + サラダ2個 → サラダ2個ともセット価格
      # 弁当3個なのでサラダは最大3個までセット価格OK
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 3 },
        { catalog: catalogs(:salad), quantity: 2 }
      ]

      result = Sales::PriceCalculator.new(cart_items).send(:apply_pricing_rules)

      salad_item = result.find { |i| i[:catalog].side_menu? }
      assert_equal 150, salad_item[:unit_price]
      assert_equal 2, salad_item[:quantity]
    end

    test "apply_pricing_rules uses regular price when no bento in cart" do
      # サラダのみ → 通常価格
      cart_items = [
        { catalog: catalogs(:salad), quantity: 2 }
      ]

      result = Sales::PriceCalculator.new(cart_items).send(:apply_pricing_rules)

      salad_item = result.first
      assert_equal 250, salad_item[:unit_price]
      assert_equal catalog_prices(:salad_regular).id, salad_item[:catalog_price_id]
    end

    # ===== 10.3 割引適用ロジックテスト =====

    test "apply_discounts returns empty details when no discount_ids" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).send(:apply_discounts)

      assert_equal [], result[:discount_details]
      assert_equal 0, result[:total_discount_amount]
    end

    test "apply_discounts applies coupon when bento exists" do
      # 弁当1個 + 50円クーポン → 50円割引
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]
      discount_ids = [ discounts(:fifty_yen_discount).id ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).send(:apply_discounts)

      assert_equal 1, result[:discount_details].length
      detail = result[:discount_details].first
      assert_equal discounts(:fifty_yen_discount).id, detail[:discount_id]
      assert_equal "50円割引クーポン", detail[:discount_name]
      assert_equal 50, detail[:discount_amount]
      assert detail[:applicable]
      assert_equal 50, result[:total_discount_amount]
    end

    test "apply_discounts calculates coupon based on bento quantity" do
      # 弁当3個 + 50円クーポン（弁当1個につき1枚） → 150円割引
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 3 }
      ]
      discount_ids = [ discounts(:fifty_yen_discount).id ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).send(:apply_discounts)

      assert_equal 150, result[:total_discount_amount]
    end

    test "apply_discounts calculates coupon based on total bento quantity from multiple items" do
      # 弁当A 3個 + 弁当B 2個 + 50円クーポン → 5個 × 50円 = 250円割引
      # Requirement 13.2, 13.8: 個数ベースでカウント
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 3 },
        { catalog: catalogs(:daily_bento_b), quantity: 2 }
      ]
      discount_ids = [ discounts(:fifty_yen_discount).id ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).send(:apply_discounts)

      assert_equal 250, result[:total_discount_amount]
    end

    test "apply_discounts marks discount as not applicable when no bento" do
      # サラダのみ + クーポン → 適用不可
      cart_items = [
        { catalog: catalogs(:salad), quantity: 2 }
      ]
      discount_ids = [ discounts(:fifty_yen_discount).id ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).send(:apply_discounts)

      detail = result[:discount_details].first
      assert_not detail[:applicable]
      assert_equal 0, detail[:discount_amount]
      assert_equal 0, result[:total_discount_amount]
    end

    test "apply_discounts sums multiple discounts" do
      # 弁当2個 + 50円クーポン + 100円クーポン → 100 + 200 = 300円割引
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 }
      ]
      discount_ids = [
        discounts(:fifty_yen_discount).id,
        discounts(:hundred_yen_discount).id
      ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).send(:apply_discounts)

      assert_equal 2, result[:discount_details].length
      assert_equal 300, result[:total_discount_amount]
    end

    test "apply_discounts skips expired discounts" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]
      discount_ids = [ discounts(:expired_discount).id ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).send(:apply_discounts)

      # 期限切れは含まれない
      assert_equal 0, result[:discount_details].length
      assert_equal 0, result[:total_discount_amount]
    end

    # ===== 10.4 calculate 統合テスト =====

    test "calculate computes subtotal from regular prices" do
      # 弁当1個 @550円 → 小計 550円, 最終 550円
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_equal 550, result[:subtotal]
      assert_equal 550, result[:final_total]
    end

    test "calculate computes subtotal with multiple items" do
      # 弁当A 2個 @550円 + 弁当B 1個 @500円 → 小計 1600円
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 },
        { catalog: catalogs(:daily_bento_b), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_equal 1600, result[:subtotal]
      assert_equal 1600, result[:final_total]
    end

    test "calculate applies bundle price to subtotal" do
      # 弁当1個 @550円 + サラダ1個 @150円（セット価格） → 小計 700円
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_equal 700, result[:subtotal]
      assert_equal 700, result[:final_total]
    end

    test "calculate applies split pricing for salad" do
      # 弁当1個 @550円 + サラダ3個（1個@150 + 2個@250） → 小計 1200円
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 3 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      # 550 + 150 + 500 = 1200
      assert_equal 1200, result[:subtotal]
    end

    test "calculate applies discount and computes final_total" do
      # 弁当2個 @550円 = 小計 1100円 - 50円クーポン × 2 = 100円割引 → 最終 1000円
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 }
      ]
      discount_ids = [ discounts(:fifty_yen_discount).id ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).calculate

      assert_equal 1100, result[:subtotal]
      assert_equal 100, result[:total_discount_amount]
      assert_equal 1000, result[:final_total]
    end

    test "calculate combines pricing rules and discounts" do
      # Requirement 14: 弁当1個 @550円 + サラダ1個 @150円 = 小計 700円
      # Requirement 13: 50円クーポン × 1個 = 50円割引 → 最終 650円
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 1 }
      ]
      discount_ids = [ discounts(:fifty_yen_discount).id ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).calculate

      assert_equal 700, result[:subtotal]
      assert_equal 50, result[:total_discount_amount]
      assert_equal 650, result[:final_total]
    end

    test "calculate returns items_with_prices with correct structure" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_equal 1, result[:items_with_prices].length
      item = result[:items_with_prices].first
      assert_equal catalogs(:daily_bento_a), item[:catalog]
      assert_equal 2, item[:quantity]
      assert_equal 550, item[:unit_price]
      assert_not_nil item[:catalog_price_id]
    end

    test "calculate does not go below zero" do
      # 弁当1個 @550円 - 100円クーポン × 1 = 最終 450円
      # （割引が小計を超えないケース）
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]
      discount_ids = [ discounts(:hundred_yen_discount).id ]

      result = Sales::PriceCalculator.new(cart_items, discount_ids: discount_ids).calculate

      assert_equal 550, result[:subtotal]
      assert_equal 100, result[:total_discount_amount]
      assert_equal 450, result[:final_total]
      assert result[:final_total] >= 0
    end

    # ===== 41.4 価格存在検証テスト (Requirement 17) =====

    test "calculate raises MissingPriceError when regular price is missing" do
      # miso_soup には価格が設定されていない
      cart_items = [
        { catalog: catalogs(:miso_soup), quantity: 1 }
      ]

      error = assert_raises(Sales::PriceCalculator::MissingPriceError) do
        Sales::PriceCalculator.new(cart_items).calculate
      end

      assert_includes error.message, "味噌汁"
      assert_includes error.message, "regular"
      assert_not_nil error.missing_prices
      assert_equal 1, error.missing_prices.length
    end

    test "calculate raises MissingPriceError with multiple missing prices" do
      # miso_soup と discontinued_bento には価格が設定されていない
      cart_items = [
        { catalog: catalogs(:miso_soup), quantity: 1 },
        { catalog: catalogs(:discontinued_bento), quantity: 1 }
      ]

      error = assert_raises(Sales::PriceCalculator::MissingPriceError) do
        Sales::PriceCalculator.new(cart_items).calculate
      end

      assert_equal 2, error.missing_prices.length
      catalog_names = error.missing_prices.map { |mp| mp[:catalog_name] }
      assert_includes catalog_names, "味噌汁"
      assert_includes catalog_names, "販売終了弁当"
    end

    test "MissingPriceError contains catalog_name and price_kind" do
      cart_items = [
        { catalog: catalogs(:miso_soup), quantity: 1 }
      ]

      error = assert_raises(Sales::PriceCalculator::MissingPriceError) do
        Sales::PriceCalculator.new(cart_items).calculate
      end

      missing = error.missing_prices.first
      assert_equal catalogs(:miso_soup).id, missing[:catalog_id]
      assert_equal "味噌汁", missing[:catalog_name]
      assert_equal "regular", missing[:price_kind]
    end

    test "calculate succeeds when all required prices exist" do
      # すべての価格が設定されている場合はエラーなし
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_not_nil result[:items_with_prices]
      assert_equal 700, result[:subtotal]
    end
  end
end
