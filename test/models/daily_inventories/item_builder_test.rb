# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class ItemBuilderTest < ActiveSupport::TestCase
    fixtures :catalogs

    setup do
      @bento_a = catalogs(:daily_bento_a)
      @bento_b = catalogs(:daily_bento_b)
      @catalogs = [ @bento_a, @bento_b ]
    end

    test "from_params builds items with catalog metadata from submitted hash" do
      submitted = {
        @bento_a.id.to_s => { selected: "1", stock: "15" },
        @bento_b.id.to_s => { selected: "1", stock: "5" }
      }

      items = ItemBuilder.from_params(@catalogs, submitted)

      assert_equal 2, items.size
      item_a = items.find { |i| i.catalog_id == @bento_a.id }
      assert item_a.selected?
      assert_equal 15, item_a.stock
      assert_equal @bento_a.name, item_a.catalog_name
      assert_equal @bento_a.category, item_a.category
    end

    test "from_params uses defaults when submitted is empty" do
      items = ItemBuilder.from_params(@catalogs, {})

      items.each do |item|
        assert_not item.selected?
        assert_equal InventoryItem::DEFAULT_STOCK, item.stock
      end
    end

    test "from_params ignores unexpected keys in submitted" do
      submitted = {
        @bento_a.id.to_s => { selected: "1", stock: "10", unknown_key: "ignored" }
      }

      items = ItemBuilder.from_params(@catalogs, submitted)
      item_a = items.find { |i| i.catalog_id == @bento_a.id }

      assert item_a.selected?
      assert_equal 10, item_a.stock
    end

    test "from_inventories builds items from DB records with mixed presence" do
      location = Location.create!(name: "builder テスト販売先", status: :active)
      inv = DailyInventory.create!(
        location: location, catalog: @bento_a,
        inventory_date: Date.current, stock: 20, reserved_stock: 0
      )
      inventories_by_catalog_id = { @bento_a.id => inv }

      items = ItemBuilder.from_inventories(@catalogs, inventories_by_catalog_id)

      item_a = items.find { |i| i.catalog_id == @bento_a.id }
      assert item_a.selected?
      assert_equal 20, item_a.stock

      item_b = items.find { |i| i.catalog_id == @bento_b.id }
      assert_not item_b.selected?
      assert_equal InventoryItem::DEFAULT_STOCK, item_b.stock
    end
  end
end
