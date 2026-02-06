# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class InventoryItemTest < ActiveSupport::TestCase
    test "initializes with defaults and accepts custom values" do
      item = InventoryItem.new(catalog_id: 1, catalog_name: "テスト弁当")

      assert_equal 1, item.catalog_id
      assert_equal "テスト弁当", item.catalog_name
      assert_not item.selected?
      assert_equal InventoryItem::DEFAULT_STOCK, item.stock
      assert_nil item.category

      custom = InventoryItem.new(catalog_id: 2, catalog_name: "特製弁当", category: "bento", selected: true, stock: 20)

      assert custom.selected?
      assert_equal 20, custom.stock
      assert_equal "bento", custom.category
    end
  end
end
