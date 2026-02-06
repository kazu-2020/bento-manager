# frozen_string_literal: true

require "test_helper"

module Sales
  class CartItemTypeTest < ActiveSupport::TestCase
    fixtures :locations, :catalogs, :catalog_prices, :daily_inventories

    setup do
      @type = CartItemType.new
      @inventory = daily_inventories(:city_hall_bento_a_today)
    end

    test "casts hash to CartItem with integer and string quantity" do
      result = @type.cast(inventory: @inventory, quantity: 3)
      assert_instance_of CartItem, result
      assert_equal @inventory, result.inventory
      assert_equal 3, result.quantity

      string_qty = @type.cast(inventory: @inventory, quantity: "5")
      assert_instance_of CartItem, string_qty
      assert_equal 5, string_qty.quantity
    end

    test "returns CartItem as-is and nil for unsupported types" do
      item = CartItem.new(inventory: @inventory, quantity: 2)
      assert_same item, @type.cast(item)

      assert_nil @type.cast("invalid")
      assert_nil @type.cast(123)
    end
  end
end
