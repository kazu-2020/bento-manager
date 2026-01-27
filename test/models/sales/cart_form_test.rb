# frozen_string_literal: true

require "test_helper"

module Sales
  class CartFormTest < ActiveSupport::TestCase
    fixtures :locations, :catalogs, :catalog_prices, :catalog_pricing_rules, :daily_inventories, :discounts, :coupons

    setup do
      @location = locations(:city_hall)
      @inventories = @location.today_inventories.includes(:catalog).order("catalogs.name")
      @discounts = Discount.active
      @bento_a = catalogs(:daily_bento_a)
      @salad = catalogs(:salad)
    end

    # =====================================================================
    # 初期化テスト
    # =====================================================================

    test "initializes with all items at quantity 0" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      assert_equal @inventories.count, form.items.count
      form.items.each do |item|
        assert_equal 0, item.quantity
        assert_not item.in_cart?
      end
    end

    test "initializes with submitted quantities" do
      submitted = {
        @bento_a.id.to_s => { "quantity" => "3" }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      bento_item = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert_equal 3, bento_item.quantity
      assert bento_item.in_cart?
    end

    test "initializes with submitted customer_type" do
      submitted = { "customer_type" => "staff" }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_equal "staff", form.customer_type
    end

    test "initializes with submitted coupon quantities" do
      discount = discounts(:fifty_yen_discount)
      submitted = {
        "coupon" => { discount.id.to_s => { "quantity" => "1" } }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_equal 1, form.coupon_quantity(discount)
    end

    # =====================================================================
    # カテゴリグルーピングテスト
    # =====================================================================

    test "bento_items returns only bento category items" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      form.bento_items.each do |item|
        assert item.bento?
      end
      assert form.bento_items.any?
    end

    test "side_menu_items returns only side_menu category items" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      form.side_menu_items.each do |item|
        assert item.side_menu?
      end
      assert form.side_menu_items.any?
    end

    # =====================================================================
    # カート状態テスト
    # =====================================================================

    test "cart_items returns only items with quantity > 0" do
      submitted = {
        @bento_a.id.to_s => { "quantity" => "2" },
        @salad.id.to_s => { "quantity" => "0" }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_equal 1, form.cart_items.count
      assert_equal @bento_a.id, form.cart_items.first.catalog_id
    end

    test "has_items_in_cart? returns true when items in cart" do
      submitted = { @bento_a.id.to_s => { "quantity" => "1" } }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert form.has_items_in_cart?
    end

    test "has_items_in_cart? returns false when cart is empty" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      assert_not form.has_items_in_cart?
    end

    test "total_bento_quantity sums bento items in cart" do
      bento_b = catalogs(:daily_bento_b)
      submitted = {
        @bento_a.id.to_s => { "quantity" => "2" },
        bento_b.id.to_s => { "quantity" => "3" },
        @salad.id.to_s => { "quantity" => "1" }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_equal 5, form.total_bento_quantity
    end

    # =====================================================================
    # PriceCalculator 連携テスト
    # =====================================================================

    test "cart_items_for_calculator returns hash array for PriceCalculator" do
      submitted = { @bento_a.id.to_s => { "quantity" => "2" } }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      result = form.cart_items_for_calculator
      assert_equal 1, result.count
      assert_equal @bento_a, result.first[:catalog]
      assert_equal 2, result.first[:quantity]
    end

    test "price_result returns calculated prices" do
      submitted = { @bento_a.id.to_s => { "quantity" => "1" } }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      result = form.price_result
      assert_equal 550, result[:subtotal]
      assert_equal 550, result[:final_total]
    end

    test "price_result with bento and salad applies bundle price" do
      submitted = {
        @bento_a.id.to_s => { "quantity" => "1" },
        @salad.id.to_s => { "quantity" => "1" }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      result = form.price_result
      # 弁当550円 + サラダ150円（セット価格）= 700円
      assert_equal 700, result[:subtotal]
      assert_equal 700, result[:final_total]
    end

    test "price_result returns empty result when cart is empty" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      result = form.price_result
      assert_equal 0, result[:subtotal]
      assert_equal 0, result[:final_total]
      assert_empty result[:items_with_prices]
    end

    # =====================================================================
    # 割引テスト
    # =====================================================================

    test "selected_discount_ids returns IDs of coupons with quantity > 0" do
      discount = discounts(:fifty_yen_discount)
      submitted = {
        "coupon" => { discount.id.to_s => { "quantity" => "1" } }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_includes form.selected_discount_ids, discount.id
    end

    test "selected_discount_ids excludes coupons with quantity 0" do
      discount = discounts(:fifty_yen_discount)
      submitted = {
        "coupon" => { discount.id.to_s => { "quantity" => "0" } }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_not_includes form.selected_discount_ids, discount.id
    end

    test "discount_quantities_for_calculator returns selected coupon quantities" do
      discount = discounts(:fifty_yen_discount)
      submitted = {
        "coupon" => { discount.id.to_s => { "quantity" => "2" } }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      result = form.discount_quantities_for_calculator
      assert_equal({ discount.id => 2 }, result)
    end

    test "discount_quantities_for_calculator excludes coupons with quantity 0" do
      discount = discounts(:fifty_yen_discount)
      submitted = {
        "coupon" => { discount.id.to_s => { "quantity" => "0" } }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      result = form.discount_quantities_for_calculator
      assert_empty result
    end

    test "弁当2個にクーポン1枚を使うと50円のみ割引される" do
      discount = discounts(:fifty_yen_discount)
      submitted = {
        @bento_a.id.to_s => { "quantity" => "2" },
        "coupon" => { discount.id.to_s => { "quantity" => "1" } }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      result = form.price_result
      assert_equal 1100, result[:subtotal]
      assert_equal 50, result[:total_discount_amount]
      assert_equal 1050, result[:final_total]
    end

    test "price_result with discount applied" do
      discount = discounts(:fifty_yen_discount)
      submitted = {
        @bento_a.id.to_s => { "quantity" => "1" },
        "coupon" => { discount.id.to_s => { "quantity" => "1" } }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      result = form.price_result
      assert_equal 550, result[:subtotal]
      # 50円割引クーポン（弁当1個 × max_per_bento_quantity 1 × 50円 = 50円割引）
      assert_equal 50, result[:total_discount_amount]
      assert_equal 500, result[:final_total]
    end

    # =====================================================================
    # バリデーション・送信可否テスト
    # =====================================================================

    test "submittable? returns true with items and customer_type" do
      submitted = {
        @bento_a.id.to_s => { "quantity" => "1" },
        "customer_type" => "staff"
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert form.submittable?
    end

    test "submittable? returns false without items" do
      submitted = { "customer_type" => "staff" }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_not form.submittable?
    end

    test "submittable? returns true with default customer_type" do
      submitted = { @bento_a.id.to_s => { "quantity" => "1" } }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert form.submittable?
      assert_equal "citizen", form.customer_type
    end

    test "valid? returns true with items and customer_type" do
      submitted = {
        @bento_a.id.to_s => { "quantity" => "1" },
        "customer_type" => "staff"
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert form.valid?
      assert_empty form.errors
    end

    test "valid? returns false without items and adds base error" do
      submitted = { "customer_type" => "staff" }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_not form.valid?
      assert form.errors[:base].any?
    end

    test "valid? returns true with default customer_type when items exist" do
      submitted = { @bento_a.id.to_s => { "quantity" => "1" } }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert form.valid?
      assert_equal "citizen", form.customer_type
    end

    # =====================================================================
    # ルートヘルパーテスト
    # =====================================================================

    test "form_with_options returns url and method for sales" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      expected = { url: "/pos/locations/#{@location.id}/sales", method: :post }
      assert_equal expected, form.form_with_options
    end

    test "form_state_options returns url and method for form state" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      expected = { url: "/pos/locations/#{@location.id}/sales/form_state", method: :post }
      assert_equal expected, form.form_state_options
    end
  end
end
