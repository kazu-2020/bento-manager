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
  end
end
