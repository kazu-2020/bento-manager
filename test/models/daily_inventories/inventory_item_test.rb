# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class InventoryItemTest < ActiveSupport::TestCase
    setup do
      @item = InventoryItem.new(catalog_id: 1, catalog_name: "テスト弁当")
    end

    test "initializes with defaults" do
      assert_equal 1, @item.catalog_id
      assert_equal "テスト弁当", @item.catalog_name
      assert_not @item.selected?
      assert_equal InventoryItem::DEFAULT_STOCK, @item.stock
    end

    test "initializes with custom values" do
      item = InventoryItem.new(catalog_id: 2, catalog_name: "特製弁当", selected: true, stock: 20)

      assert item.selected?
      assert_equal 20, item.stock
    end

    test "toggle switches selected state" do
      assert_not @item.selected?

      @item.toggle
      assert @item.selected?

      @item.toggle
      assert_not @item.selected?
    end

    test "increment increases stock by 1" do
      @item.increment

      assert_equal InventoryItem::DEFAULT_STOCK + 1, @item.stock
    end

    test "increment does not exceed MAX_STOCK" do
      @item.stock = InventoryItem::MAX_STOCK

      @item.increment

      assert_equal InventoryItem::MAX_STOCK, @item.stock
    end

    test "decrement decreases stock by 1" do
      @item.decrement

      assert_equal InventoryItem::DEFAULT_STOCK - 1, @item.stock
    end

    test "decrement does not go below MIN_STOCK" do
      @item.stock = InventoryItem::MIN_STOCK

      @item.decrement

      assert_equal InventoryItem::MIN_STOCK, @item.stock
    end

    test "update_stock sets value within bounds" do
      @item.update_stock(25)
      assert_equal 25, @item.stock

      @item.update_stock(0)
      assert_equal InventoryItem::MIN_STOCK, @item.stock

      @item.update_stock(1000)
      assert_equal InventoryItem::MAX_STOCK, @item.stock
    end

    test "update_stock converts string to integer" do
      @item.update_stock("15")

      assert_equal 15, @item.stock
    end

    test "to_state_entry returns state hash" do
      @item.toggle
      @item.update_stock(20)

      assert_equal({ selected: true, stock: 20 }, @item.to_state_entry)
    end

    test "to_inventory_param returns param hash" do
      @item.update_stock(15)

      assert_equal({ catalog_id: 1, stock: 15 }, @item.to_inventory_param)
    end
  end
end
