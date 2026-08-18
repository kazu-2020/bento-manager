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

  test "指定日の追加発注を商品ごとに合計する" do
    location = Location.create!(name: "追加発注集計販売先", status: :active)
    DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current, stock: 20, reserved_stock: 0
    )
    AdditionalOrder.create_with_inventory!(
      location: location, catalog_id: catalogs(:daily_bento_a).id,
      quantity: 5, order_at: Time.current
    )
    AdditionalOrder.create_with_inventory!(
      location: location, catalog_id: catalogs(:daily_bento_a).id,
      quantity: 3, order_at: Time.current
    )
    AdditionalOrder.create_with_inventory!(
      location: location, catalog_id: catalogs(:salad).id,
      quantity: 2, order_at: Time.current
    )

    quantities = AdditionalOrder.quantities_by_catalog_id(location: location)

    assert_equal 8, quantities[catalogs(:daily_bento_a).id]
    assert_equal 2, quantities[catalogs(:salad).id]
  end

  test "別の日や別の販売先の追加発注は集計に含めない" do
    location = Location.create!(name: "追加発注集計対象販売先", status: :active)
    other_location = Location.create!(name: "追加発注集計対象外販売先", status: :active)
    AdditionalOrder.create_with_inventory!(
      location: location, catalog_id: catalogs(:daily_bento_a).id,
      quantity: 5, order_at: 1.day.ago
    )
    AdditionalOrder.create_with_inventory!(
      location: other_location, catalog_id: catalogs(:daily_bento_a).id,
      quantity: 7, order_at: Time.current
    )

    assert_empty AdditionalOrder.quantities_by_catalog_id(location: location)
    assert_equal 5, AdditionalOrder.quantities_by_catalog_id(location: location, date: Date.current - 1.day)
      .fetch(catalogs(:daily_bento_a).id)
  end
end
