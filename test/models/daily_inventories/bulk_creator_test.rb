# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class BulkCreatorTest < ActiveSupport::TestCase
    fixtures :locations, :catalogs

    setup do
      @location = Location.create!(name: "テスト販売先", status: :active)
      @bento_a = catalogs(:daily_bento_a)
      @bento_b = catalogs(:daily_bento_b)
    end

    test "creates daily inventories for selected items" do
      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_a.id, stock: 10 },
          { catalog_id: @bento_b.id, stock: 5 }
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)

      assert_difference "DailyInventory.count", 2 do
        assert creator.call
      end

      assert_equal 2, creator.created_count
      assert_nil creator.error_message
    end

    test "skips items with zero stock" do
      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_a.id, stock: 10 },
          { catalog_id: @bento_b.id, stock: 0 }
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)

      assert_difference "DailyInventory.count", 1 do
        assert creator.call
      end

      assert_equal 1, creator.created_count
    end

    test "skips items with blank stock" do
      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_a.id, stock: 10 },
          { catalog_id: @bento_b.id, stock: "" }
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)

      assert_difference "DailyInventory.count", 1 do
        assert creator.call
      end
    end

    test "skips items with negative stock" do
      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_a.id, stock: 10 },
          { catalog_id: @bento_b.id, stock: -5 }
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)

      assert_difference "DailyInventory.count", 1 do
        assert creator.call
      end
    end

    test "returns false when no valid items" do
      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_a.id, stock: 0 }
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)

      assert_no_difference "DailyInventory.count" do
        assert_not creator.call
      end

      assert_equal 0, creator.created_count
    end

    test "returns false when inventories is empty" do
      params = ActionController::Parameters.new({
        inventories: []
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)

      assert_not creator.call
      assert_equal 0, creator.created_count
    end

    test "returns false when inventories is nil" do
      params = ActionController::Parameters.new({}).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)

      assert_not creator.call
      assert_equal 0, creator.created_count
    end

    test "sets inventory_date to current date" do
      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_a.id, stock: 10 }
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)
      creator.call

      inventory = DailyInventory.last
      assert_equal Date.current, inventory.inventory_date
    end

    test "sets reserved_stock to zero" do
      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_a.id, stock: 10 }
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)
      creator.call

      inventory = DailyInventory.last
      assert_equal 0, inventory.reserved_stock
    end

    test "rolls back all changes on validation error" do
      # Create existing inventory to cause duplicate error
      DailyInventory.create!(
        location: @location,
        catalog: @bento_a,
        inventory_date: Date.current,
        stock: 5,
        reserved_stock: 0
      )

      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_b.id, stock: 10 },  # This would succeed alone
          { catalog_id: @bento_a.id, stock: 15 }   # This will fail (duplicate)
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)

      assert_no_difference "DailyInventory.count" do
        assert_not creator.call
      end

      assert_not_nil creator.error_message
    end

    test "sets error_message on validation failure" do
      # Create existing inventory to cause duplicate error
      DailyInventory.create!(
        location: @location,
        catalog: @bento_a,
        inventory_date: Date.current,
        stock: 5,
        reserved_stock: 0
      )

      params = ActionController::Parameters.new({
        inventories: [
          { catalog_id: @bento_a.id, stock: 15 }
        ]
      }).permit!

      creator = BulkCreator.new(location: @location, inventory_params: params)
      creator.call

      assert_not_nil creator.error_message
      assert_includes creator.error_message, "同じ販売先・商品・日付の組み合わせは既に存在します"
    end
  end
end
