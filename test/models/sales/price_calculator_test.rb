require "test_helper"

module Sales
  class PriceCalculatorTest < ActiveSupport::TestCase
    fixtures :catalogs, :catalog_prices, :catalog_pricing_rules, :discounts, :coupons

    # ===== 基本的な会計 =====

    test "空のカートで会計すると合計が0円になる" do
      result = Sales::PriceCalculator.new([]).calculate

      assert_equal [], result[:items_with_prices]
      assert_equal 0, result[:subtotal]
      assert_equal [], result[:discount_details]
      assert_equal 0, result[:total_discount_amount]
      assert_equal 0, result[:final_total]
    end

    test "弁当1個(550円)を会計すると合計550円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_equal 550, result[:subtotal]
      assert_equal 550, result[:final_total]

      item = result[:items_with_prices].first
      assert_equal 550, item[:unit_price]
      assert_equal catalog_prices(:daily_bento_a_regular).id, item[:catalog_price_id]
    end

    test "弁当A2個(550円)と弁当B1個(500円)を会計すると合計1600円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 },
        { catalog: catalogs(:daily_bento_b), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_equal 1600, result[:subtotal]
      assert_equal 1600, result[:final_total]
    end

    test "計算結果に必要なキーがすべて含まれる" do
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

    # ===== セット割引 ─ 弁当＋サイドメニュー =====

    test "弁当(550円)とサラダを一緒に買うとサラダがセット価格150円になり合計700円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      salad_item = result[:items_with_prices].find { |i| i[:catalog].side_menu? }
      assert_equal 150, salad_item[:unit_price]
      assert_equal catalog_prices(:salad_bundle).id, salad_item[:catalog_price_id]
      assert_equal 700, result[:subtotal]
    end

    test "弁当1個+サラダ3個ではサラダ1個が150円・2個が250円で合計1200円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 3 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      salad_items = result[:items_with_prices].select { |i| i[:catalog].side_menu? }
      bundle_item = salad_items.find { |i| i[:unit_price] == 150 }
      regular_item = salad_items.find { |i| i[:unit_price] == 250 }

      assert_not_nil bundle_item
      assert_equal 1, bundle_item[:quantity]
      assert_not_nil regular_item
      assert_equal 2, regular_item[:quantity]
      # 550 + 150 + 500 = 1200
      assert_equal 1200, result[:subtotal]
    end

    test "弁当3個あればサラダ2個とも150円のセット価格になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 3 },
        { catalog: catalogs(:salad), quantity: 2 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      salad_item = result[:items_with_prices].find { |i| i[:catalog].side_menu? }
      assert_equal 150, salad_item[:unit_price]
      assert_equal 2, salad_item[:quantity]
    end

    test "サラダだけ2個買うと通常価格250円で合計500円になる" do
      cart_items = [
        { catalog: catalogs(:salad), quantity: 2 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      salad_item = result[:items_with_prices].first
      assert_equal 250, salad_item[:unit_price]
      assert_equal catalog_prices(:salad_regular).id, salad_item[:catalog_price_id]
      assert_equal 500, result[:subtotal]
    end

    # ===== クーポン割引 =====

    test "クーポンなしで弁当1個(550円)を会計すると割引0円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]

      result = Sales::PriceCalculator.new(cart_items).calculate

      assert_equal [], result[:discount_details]
      assert_equal 0, result[:total_discount_amount]
    end

    test "弁当2個(550円)に50円クーポン1枚を使うと50円引きの1050円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 }
      ]
      discount_quantities = { discounts(:fifty_yen_discount).id => 1 }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      assert_equal 1100, result[:subtotal]
      assert_equal 50, result[:total_discount_amount]
      assert_equal 1050, result[:final_total]
    end

    test "50円クーポンで弁当1個(550円)を買うと50円引きの500円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]
      discount_quantities = { discounts(:fifty_yen_discount).id => 1 }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      assert_equal 1, result[:discount_details].length
      detail = result[:discount_details].first
      assert_equal discounts(:fifty_yen_discount).id, detail[:discount_id]
      assert_equal "50円割引クーポン", detail[:discount_name]
      assert_equal 50, detail[:discount_amount]
      assert detail[:applicable]
      assert_equal 50, result[:total_discount_amount]
      assert_equal 500, result[:final_total]
    end

    test "弁当3個(550円)に50円クーポン1枚を使うと50円引きになる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 3 }
      ]
      discount_quantities = { discounts(:fifty_yen_discount).id => 1 }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      assert_equal 50, result[:total_discount_amount]
    end

    test "弁当A3個+弁当B2個に50円クーポン1枚を使うと50円引きになる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 3 },
        { catalog: catalogs(:daily_bento_b), quantity: 2 }
      ]
      discount_quantities = { discounts(:fifty_yen_discount).id => 1 }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      assert_equal 50, result[:total_discount_amount]
    end

    test "サラダのみの購入では50円クーポンは適用されず割引0円になる" do
      cart_items = [
        { catalog: catalogs(:salad), quantity: 2 }
      ]
      discount_quantities = { discounts(:fifty_yen_discount).id => 1 }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      detail = result[:discount_details].first
      assert_not detail[:applicable]
      assert_equal 0, detail[:discount_amount]
      assert_equal 0, result[:total_discount_amount]
    end

    test "弁当2個に50円と100円のクーポンを同時に使うと合計150円引きになる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 }
      ]
      discount_quantities = {
        discounts(:fifty_yen_discount).id => 1,
        discounts(:hundred_yen_discount).id => 1
      }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      assert_equal 2, result[:discount_details].length
      assert_equal 150, result[:total_discount_amount]
    end

    test "期限切れクーポンは自動的にスキップされ割引0円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]
      discount_quantities = { discounts(:expired_discount).id => 1 }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      assert_equal 0, result[:discount_details].length
      assert_equal 0, result[:total_discount_amount]
    end

    # ===== クーポン複数枚利用 =====

    test "弁当3個(550円)に50円クーポン3枚を使うと150円引きの1500円になる" do
      cart_items = [ { catalog: catalogs(:daily_bento_a), quantity: 3 } ]
      discount_quantities = { discounts(:fifty_yen_discount).id => 3 }

      result = Sales::PriceCalculator.new(
        cart_items, discount_quantities: discount_quantities
      ).calculate

      assert_equal 1650, result[:subtotal]
      assert_equal 150, result[:total_discount_amount]
      assert_equal 1500, result[:final_total]
    end

    test "弁当2個に50円クーポン2枚と100円クーポン3枚を使うと合計400円引きになる" do
      cart_items = [ { catalog: catalogs(:daily_bento_a), quantity: 2 } ]
      discount_quantities = {
        discounts(:fifty_yen_discount).id => 2,
        discounts(:hundred_yen_discount).id => 3
      }

      result = Sales::PriceCalculator.new(
        cart_items, discount_quantities: discount_quantities
      ).calculate

      assert_equal 1100, result[:subtotal]
      assert_equal 400, result[:total_discount_amount]
      assert_equal 700, result[:final_total]
    end

    # ===== セット割引とクーポンの組み合わせ =====

    test "弁当とサラダのセット購入(700円)に50円クーポンを併用すると最終650円になる" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 1 }
      ]
      discount_quantities = { discounts(:fifty_yen_discount).id => 1 }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      assert_equal 700, result[:subtotal]
      assert_equal 50, result[:total_discount_amount]
      assert_equal 650, result[:final_total]
    end

    test "弁当1個(550円)に100円クーポンを使うと最終450円になり0円を下回らない" do
      cart_items = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ]
      discount_quantities = { discounts(:hundred_yen_discount).id => 1 }

      result = Sales::PriceCalculator.new(cart_items, discount_quantities: discount_quantities).calculate

      assert_equal 550, result[:subtotal]
      assert_equal 100, result[:total_discount_amount]
      assert_equal 450, result[:final_total]
      assert result[:final_total] >= 0
    end

    # ===== 価格未設定エラー =====

    test "価格未設定の商品を会計するとエラーになる" do
      cart_items = [
        { catalog: catalogs(:miso_soup), quantity: 1 }
      ]

      error = assert_raises(Errors::MissingPriceError) do
        Sales::PriceCalculator.new(cart_items).calculate
      end

      assert_includes error.message, "味噌汁"
      assert_includes error.message, "regular"
      assert_not_nil error.missing_prices
      assert_equal 1, error.missing_prices.length
    end

    test "複数の商品に価格が未設定の場合まとめてエラー報告される" do
      cart_items = [
        { catalog: catalogs(:miso_soup), quantity: 1 },
        { catalog: catalogs(:discontinued_bento), quantity: 1 }
      ]

      error = assert_raises(Errors::MissingPriceError) do
        Sales::PriceCalculator.new(cart_items).calculate
      end

      assert_equal 2, error.missing_prices.length
      catalog_names = error.missing_prices.map { |mp| mp[:catalog_name] }
      assert_includes catalog_names, "味噌汁"
      assert_includes catalog_names, "販売終了弁当"
    end

    test "エラーには商品名と価格種別が含まれる" do
      cart_items = [
        { catalog: catalogs(:miso_soup), quantity: 1 }
      ]

      error = assert_raises(Errors::MissingPriceError) do
        Sales::PriceCalculator.new(cart_items).calculate
      end

      missing = error.missing_prices.first
      assert_equal catalogs(:miso_soup).id, missing[:catalog_id]
      assert_equal "味噌汁", missing[:catalog_name]
      assert_equal "regular", missing[:price_kind]
    end

    test "すべての価格が設定されていれば正常に計算できる" do
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
