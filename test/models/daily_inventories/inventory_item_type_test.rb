# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class InventoryItemTypeTest < ActiveSupport::TestCase
    setup do
      @type = InventoryItemType.new
    end

    test "casts hash with symbol keys to InventoryItem" do
      result = @type.cast(catalog_id: 1, catalog_name: "弁当A", selected: true, stock: 15)

      assert_instance_of InventoryItem, result
      assert_equal 1, result.catalog_id
      assert_equal "弁当A", result.catalog_name
      assert result.selected?
      assert_equal 15, result.stock
    end

    test "casts hash with string keys to InventoryItem" do
      result = @type.cast("catalog_id" => 2, "catalog_name" => "弁当B", "selected" => false, "stock" => 20)

      assert_instance_of InventoryItem, result
      assert_equal 2, result.catalog_id
      assert_equal "弁当B", result.catalog_name
      assert_not result.selected?
      assert_equal 20, result.stock
    end

    test "casts boolean-like selected values" do
      assert @type.cast(catalog_id: 1, catalog_name: "t", selected: true, stock: 1).selected?
      assert @type.cast(catalog_id: 1, catalog_name: "t", selected: "1", stock: 1).selected?
      assert @type.cast(catalog_id: 1, catalog_name: "t", selected: "true", stock: 1).selected?
      assert_not @type.cast(catalog_id: 1, catalog_name: "t", selected: false, stock: 1).selected?
      assert_not @type.cast(catalog_id: 1, catalog_name: "t", selected: "0", stock: 1).selected?
    end

    test "returns InventoryItem as-is (idempotent)" do
      item = InventoryItem.new(catalog_id: 1, catalog_name: "弁当", selected: true, stock: 5)
      result = @type.cast(item)

      assert_same item, result
    end

    test "returns nil for unsupported types" do
      assert_nil @type.cast("invalid")
      assert_nil @type.cast(123)
    end

    test "uses DEFAULT_STOCK when stock is nil" do
      result = @type.cast(catalog_id: 1, catalog_name: "弁当")

      assert_equal InventoryItem::DEFAULT_STOCK, result.stock
    end
  end
end
