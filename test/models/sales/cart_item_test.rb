# frozen_string_literal: true

require "test_helper"

module Sales
  class CartItemTest < ActiveSupport::TestCase
    fixtures :locations, :catalogs, :catalog_prices, :daily_inventories

    setup do
      @inventory_bento = daily_inventories(:city_hall_bento_a_today)
      @inventory_salad = daily_inventories(:city_hall_salad_today)
    end

    test "initializes with inventory, delegates attributes, and casts quantity to integer" do
      item = CartItem.new(inventory: @inventory_bento)
      assert_equal @inventory_bento, item.inventory
      assert_equal 0, item.quantity
      assert_equal catalogs(:daily_bento_a), item.catalog
      assert_equal catalogs(:daily_bento_a).id, item.catalog_id
      assert_equal "日替わり弁当A", item.catalog_name
      assert_equal "bento", item.category
      assert_equal @inventory_bento.stock, item.stock

      custom = CartItem.new(inventory: @inventory_bento, quantity: 3)
      assert_equal 3, custom.quantity

      string_qty = CartItem.new(inventory: @inventory_bento, quantity: "5")
      assert_equal 5, string_qty.quantity
    end

    test "predicates reflect cart state and catalog category" do
      empty = CartItem.new(inventory: @inventory_bento, quantity: 0)
      assert_not empty.in_cart?

      in_cart = CartItem.new(inventory: @inventory_bento, quantity: 1)
      assert in_cart.in_cart?
      assert in_cart.bento?
      assert_not in_cart.side_menu?

      salad = CartItem.new(inventory: @inventory_salad)
      assert salad.side_menu?
      assert_not salad.bento?
    end

    test "sold_out? and unit_price reflect inventory and pricing state" do
      item = CartItem.new(inventory: @inventory_bento)
      assert_not item.sold_out?
      assert_equal 550, item.unit_price

      sold_out_inventory = DailyInventory.new(
        location: locations(:city_hall),
        catalog: catalogs(:daily_bento_a),
        inventory_date: Date.current,
        stock: 0,
        reserved_stock: 0
      )
      sold_out = CartItem.new(inventory: sold_out_inventory)
      assert sold_out.sold_out?

      no_price_inventory = DailyInventory.new(
        location: locations(:city_hall),
        catalog: catalogs(:miso_soup),
        inventory_date: Date.current,
        stock: 5,
        reserved_stock: 0
      )
      no_price = CartItem.new(inventory: no_price_inventory)
      assert_nil no_price.unit_price
    end
  end
end
