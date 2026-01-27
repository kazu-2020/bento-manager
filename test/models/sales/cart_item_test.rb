# frozen_string_literal: true

require "test_helper"

module Sales
  class CartItemTest < ActiveSupport::TestCase
    fixtures :locations, :catalogs, :catalog_prices, :daily_inventories

    setup do
      @inventory_bento = daily_inventories(:city_hall_bento_a_today)
      @inventory_salad = daily_inventories(:city_hall_salad_today)
    end

    test "initializes with inventory and default quantity of 0" do
      item = CartItem.new(inventory: @inventory_bento)

      assert_equal @inventory_bento, item.inventory
      assert_equal 0, item.quantity
    end

    test "initializes with specified quantity" do
      item = CartItem.new(inventory: @inventory_bento, quantity: 3)

      assert_equal 3, item.quantity
    end

    test "quantity is cast to integer from string" do
      item = CartItem.new(inventory: @inventory_bento, quantity: "5")

      assert_equal 5, item.quantity
    end

    test "delegates catalog from inventory" do
      item = CartItem.new(inventory: @inventory_bento)

      assert_equal catalogs(:daily_bento_a), item.catalog
    end

    test "catalog_id returns catalog's id" do
      item = CartItem.new(inventory: @inventory_bento)

      assert_equal catalogs(:daily_bento_a).id, item.catalog_id
    end

    test "catalog_name returns catalog's name" do
      item = CartItem.new(inventory: @inventory_bento)

      assert_equal "日替わり弁当A", item.catalog_name
    end

    test "category returns catalog's category" do
      bento_item = CartItem.new(inventory: @inventory_bento)
      salad_item = CartItem.new(inventory: @inventory_salad)

      assert_equal "bento", bento_item.category
      assert_equal "side_menu", salad_item.category
    end

    test "stock returns inventory's stock" do
      item = CartItem.new(inventory: @inventory_bento)

      assert_equal @inventory_bento.stock, item.stock
    end

    test "in_cart? returns true when quantity > 0" do
      item = CartItem.new(inventory: @inventory_bento, quantity: 1)

      assert item.in_cart?
    end

    test "in_cart? returns false when quantity is 0" do
      item = CartItem.new(inventory: @inventory_bento, quantity: 0)

      assert_not item.in_cart?
    end

    test "bento? returns true for bento catalog" do
      item = CartItem.new(inventory: @inventory_bento)

      assert item.bento?
    end

    test "bento? returns false for side_menu catalog" do
      item = CartItem.new(inventory: @inventory_salad)

      assert_not item.bento?
    end

    test "side_menu? returns true for side_menu catalog" do
      item = CartItem.new(inventory: @inventory_salad)

      assert item.side_menu?
    end

    test "side_menu? returns false for bento catalog" do
      item = CartItem.new(inventory: @inventory_bento)

      assert_not item.side_menu?
    end

    test "sold_out? returns true when stock is 0" do
      inventory = DailyInventory.new(
        location: locations(:city_hall),
        catalog: catalogs(:daily_bento_a),
        inventory_date: Date.current,
        stock: 0,
        reserved_stock: 0
      )
      item = CartItem.new(inventory: inventory)

      assert item.sold_out?
    end

    test "sold_out? returns false when stock > 0" do
      item = CartItem.new(inventory: @inventory_bento)

      assert_not item.sold_out?
    end

    test "unit_price returns regular price" do
      item = CartItem.new(inventory: @inventory_bento)

      assert_equal 550, item.unit_price
    end

    test "unit_price returns nil when no price exists" do
      inventory = DailyInventory.new(
        location: locations(:city_hall),
        catalog: catalogs(:miso_soup),
        inventory_date: Date.current,
        stock: 5,
        reserved_stock: 0
      )
      item = CartItem.new(inventory: inventory)

      assert_nil item.unit_price
    end
  end
end
