# frozen_string_literal: true

require "test_helper"

module Sales
  class CartItemTypeTest < ActiveSupport::TestCase
    fixtures :locations, :catalogs, :catalog_prices, :daily_inventories

    setup do
      @type = CartItemType.new
      @inventory = daily_inventories(:city_hall_bento_a_today)
    end

    test "casts Hash to CartItem" do
      result = @type.cast(inventory: @inventory, quantity: 3)

      assert_instance_of CartItem, result
      assert_equal @inventory, result.inventory
      assert_equal 3, result.quantity
    end

    test "casts Hash with string quantity" do
      result = @type.cast(inventory: @inventory, quantity: "5")

      assert_instance_of CartItem, result
      assert_equal 5, result.quantity
    end

    test "returns CartItem as-is (idempotent)" do
      item = CartItem.new(inventory: @inventory, quantity: 2)
      result = @type.cast(item)

      assert_same item, result
    end

    test "returns nil for unsupported types" do
      assert_nil @type.cast("invalid")
      assert_nil @type.cast(123)
    end
  end
end
