# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class InventoryItemTypeTest < ActiveSupport::TestCase
    setup do
      @type = InventoryItemType.new
    end

    test "casts hash to InventoryItem with symbol/string keys and boolean-like selected" do
      result = @type.cast(catalog_id: 1, catalog_name: "弁当A", selected: true, stock: 15)
      assert_instance_of InventoryItem, result
      assert_equal 1, result.catalog_id
      assert result.selected?
      assert_equal 15, result.stock

      string_keys = @type.cast("catalog_id" => 2, "catalog_name" => "弁当B", "selected" => false, "stock" => 20)
      assert_instance_of InventoryItem, string_keys
      assert_equal 2, string_keys.catalog_id
      assert_not string_keys.selected?

      assert @type.cast(catalog_id: 1, catalog_name: "t", selected: "1", stock: 1).selected?
      assert @type.cast(catalog_id: 1, catalog_name: "t", selected: "true", stock: 1).selected?
      assert_not @type.cast(catalog_id: 1, catalog_name: "t", selected: "0", stock: 1).selected?
    end

    test "returns InventoryItem as-is and nil for unsupported types" do
      item = InventoryItem.new(catalog_id: 1, catalog_name: "弁当", selected: true, stock: 5)
      assert_same item, @type.cast(item)

      assert_nil @type.cast("invalid")
      assert_nil @type.cast(123)

      default = @type.cast(catalog_id: 1, catalog_name: "弁当")
      assert_equal InventoryItem::DEFAULT_STOCK, default.stock
    end
  end
end
