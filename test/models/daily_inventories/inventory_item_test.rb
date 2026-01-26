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

    test "to_inventory_param returns param hash" do
      @item.update_stock(15)

      assert_equal({ catalog_id: 1, stock: 15 }, @item.to_inventory_param)
    end
  end
end
