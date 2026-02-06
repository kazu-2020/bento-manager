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

    test "カートを構築し商品の数量・顧客種別・クーポンを入力できる" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)
      assert_equal @inventories.count, form.items.count
      form.items.each do |item|
        assert_equal 0, item.quantity
        assert_not item.in_cart?
      end
      assert_not form.has_items_in_cart?

      submitted = {
        @bento_a.id.to_s => { "quantity" => "3" },
        "customer_type" => "staff"
      }
      form_with_input = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)
      bento_item = form_with_input.items.find { |i| i.catalog_id == @bento_a.id }
      assert_equal 3, bento_item.quantity
      assert bento_item.in_cart?
      assert form_with_input.has_items_in_cart?
      assert_equal "staff", form_with_input.customer_type

      discount = discounts(:fifty_yen_discount)
      coupon_submitted = { "coupon" => { discount.id.to_s => { "quantity" => "1" } } }
      form_with_coupon = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: coupon_submitted)
      assert_equal 1, form_with_coupon.coupon_quantity(discount)
    end

    test "商品をカテゴリごとに分類できる" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      assert form.bento_items.any?
      form.bento_items.each { |item| assert item.bento? }

      assert form.side_menu_items.any?
      form.side_menu_items.each { |item| assert item.side_menu? }
    end

    test "カート内の商品を絞り込み弁当の合計数量を計算できる" do
      bento_b = catalogs(:daily_bento_b)
      submitted = {
        @bento_a.id.to_s => { "quantity" => "2" },
        bento_b.id.to_s => { "quantity" => "3" },
        @salad.id.to_s => { "quantity" => "0" }
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)

      assert_equal 2, form.cart_items.count
      assert_equal @bento_a.id, form.cart_items.find { |i| i.catalog_id == @bento_a.id }.catalog_id
      assert_equal 5, form.total_bento_quantity
    end

    test "カートの合計金額を計算しセット割引が適用される" do
      form_empty = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)
      empty_result = form_empty.price_result
      assert_equal 0, empty_result[:subtotal]
      assert_equal 0, empty_result[:final_total]
      assert_empty empty_result[:items_with_prices]

      submitted_single = { @bento_a.id.to_s => { "quantity" => "1" } }
      form_single = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted_single)
      single_result = form_single.price_result
      assert_equal 550, single_result[:subtotal]
      assert_equal 550, single_result[:final_total]

      submitted_bundle = {
        @bento_a.id.to_s => { "quantity" => "1" },
        @salad.id.to_s => { "quantity" => "1" }
      }
      form_bundle = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted_bundle)
      bundle_result = form_bundle.price_result
      assert_equal 700, bundle_result[:subtotal]
      assert_equal 700, bundle_result[:final_total]
    end

    test "クーポンを選択して割引額が反映される" do
      discount = discounts(:fifty_yen_discount)

      coupon_submitted = { "coupon" => { discount.id.to_s => { "quantity" => "1" } } }
      form_select = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: coupon_submitted)
      assert_includes form_select.selected_discount_ids, discount.id

      zero_submitted = { "coupon" => { discount.id.to_s => { "quantity" => "0" } } }
      form_zero = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: zero_submitted)
      assert_not_includes form_zero.selected_discount_ids, discount.id
      assert_empty form_zero.discount_quantities_for_calculator

      full_submitted = {
        @bento_a.id.to_s => { "quantity" => "2" },
        "coupon" => { discount.id.to_s => { "quantity" => "1" } }
      }
      form_with_discount = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: full_submitted)
      result = form_with_discount.price_result
      assert_equal 1100, result[:subtotal]
      assert_equal 50, result[:total_discount_amount]
      assert_equal 1050, result[:final_total]

      single_submitted = {
        @bento_a.id.to_s => { "quantity" => "1" },
        "coupon" => { discount.id.to_s => { "quantity" => "1" } }
      }
      form_single = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: single_submitted)
      single_result = form_single.price_result
      assert_equal 550, single_result[:subtotal]
      assert_equal 50, single_result[:total_discount_amount]
      assert_equal 500, single_result[:final_total]
    end

    test "商品未選択ではバリデーションエラーになり商品を選ぶと送信できる" do
      empty_form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: { "customer_type" => "staff" })
      assert_not empty_form.valid?
      assert empty_form.errors[:base].any?

      submitted = {
        @bento_a.id.to_s => { "quantity" => "1" },
        "customer_type" => "staff"
      }
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: submitted)
      assert form.valid?
      assert_empty form.errors

      default_type = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts, submitted: { @bento_a.id.to_s => { "quantity" => "1" } })
      assert default_type.valid?
      assert_equal "citizen", default_type.customer_type
    end

    test "form_with_options and form_state_options return correct URLs" do
      form = CartForm.new(location: @location, inventories: @inventories, discounts: @discounts)

      assert_equal({ url: "/pos/locations/#{@location.id}/sales", method: :post }, form.form_with_options)
      assert_equal({ url: "/pos/locations/#{@location.id}/sales/form_state", method: :post }, form.form_state_options)
    end
  end
end
