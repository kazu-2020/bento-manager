require "test_helper"

class AdditionalOrderTest < ActiveSupport::TestCase
  fixtures :locations, :catalogs, :employees, :daily_inventories

  test "validations" do
    @subject = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_at: Time.current,
      quantity: 5
    )

    must validate_presence_of(:order_at)
    must validate_presence_of(:quantity)
    must validate_numericality_of(:quantity).is_greater_than(0)
  end

  test "associations" do
    @subject = AdditionalOrder.new

    must belong_to(:location)
    must belong_to(:catalog)
    must belong_to(:employee).optional
  end

  test "追加発注すると対応する在庫が加算される" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_stock = inventory.stock

    AdditionalOrder.create_with_inventory!(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_at: inventory.inventory_date.to_time,
      quantity: 5
    )

    inventory.reload
    assert_equal initial_stock + 5, inventory.stock

    future_date = Date.current + 365

    assert_difference "DailyInventory.count" do
      AdditionalOrder.create_with_inventory!(
        location: locations(:city_hall),
        catalog: catalogs(:daily_bento_a),
        order_at: future_date.to_time,
        quantity: 10
      )
    end

    new_inventory = DailyInventory.find_by(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: future_date
    )
    assert_equal 10, new_inventory.stock
  end

  test "追加発注が不正な場合は在庫も変更されない" do
    inventory = daily_inventories(:city_hall_bento_a_today)

    assert_no_difference "AdditionalOrder.count" do
      assert_no_changes -> { inventory.reload.stock } do
        assert_raises ActiveRecord::RecordInvalid do
          AdditionalOrder.create_with_inventory!(
            location: locations(:city_hall),
            catalog: catalogs(:daily_bento_a),
            order_at: Time.current,
            quantity: 0
          )
        end
      end
    end
  end
end
