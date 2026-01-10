require "test_helper"

class AdditionalOrderTest < ActiveSupport::TestCase
  fixtures :locations, :catalogs, :employees, :daily_inventories

  # =============================================================================
  # Task 12.1: モデル存在・アソシエーションテスト
  # =============================================================================

  test "有効な属性で作成できる" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5,
      employee: employees(:verified_employee)
    )
    assert order.valid?
  end

  test "location との関連が正しく設定されている" do
    order = AdditionalOrder.create!(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5
    )
    assert_equal locations(:city_hall), order.location
  end

  test "catalog との関連が正しく設定されている" do
    order = AdditionalOrder.create!(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5
    )
    assert_equal catalogs(:daily_bento_a), order.catalog
  end

  test "employee との関連が正しく設定されている" do
    order = AdditionalOrder.create!(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5,
      employee: employees(:verified_employee)
    )
    assert_equal employees(:verified_employee), order.employee
  end

  test "employee なしでも作成できる" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5,
      employee: nil
    )
    assert order.valid?
  end

  # =============================================================================
  # Task 12.2: バリデーションテスト
  # =============================================================================

  test "location は必須" do
    order = AdditionalOrder.new(
      location: nil,
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5
    )
    assert_not order.valid?
    assert_includes order.errors[:location], "を入力してください"
  end

  test "catalog は必須" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: nil,
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5
    )
    assert_not order.valid?
    assert_includes order.errors[:catalog], "を入力してください"
  end

  test "order_date は必須" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: nil,
      order_time: Time.current,
      quantity: 5
    )
    assert_not order.valid?
    assert_includes order.errors[:order_date], "を入力してください"
  end

  test "order_time は必須" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: nil,
      quantity: 5
    )
    assert_not order.valid?
    assert_includes order.errors[:order_time], "を入力してください"
  end

  test "quantity は必須" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: nil
    )
    assert_not order.valid?
    assert_includes order.errors[:quantity], "を入力してください"
  end

  test "quantity は1以上である必要がある" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 0
    )
    assert_not order.valid?
    assert_includes order.errors[:quantity], "は0より大きい値にしてください"
  end

  test "quantity が負の値は無効" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: -1
    )
    assert_not order.valid?
    assert_includes order.errors[:quantity], "は0より大きい値にしてください"
  end

  test "quantity が1は有効" do
    order = AdditionalOrder.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 1
    )
    assert order.valid?
  end

  # =============================================================================
  # Task 12.4: create_with_inventory! テスト（在庫加算）
  # =============================================================================

  test "create_with_inventory! で該当する DailyInventory の在庫が加算される" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_stock = inventory.stock

    order = AdditionalOrder.create_with_inventory!(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5
    )

    inventory.reload
    assert_equal initial_stock + 5, inventory.stock
  end

  test "create_with_inventory! で該当する DailyInventory が存在しない場合は作成されて在庫が加算される" do
    # 明日の在庫は存在しないはず
    assert_nil DailyInventory.find_by(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day
    )

    assert_difference "DailyInventory.count" do
      AdditionalOrder.create_with_inventory!(
        location: locations(:city_hall),
        catalog: catalogs(:daily_bento_a),
        order_date: Date.current + 1.day,
        order_time: Time.current,
        quantity: 10
      )
    end

    inventory = DailyInventory.find_by(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day
    )
    assert_not_nil inventory
    assert_equal 10, inventory.stock
  end

  test "create_with_inventory! は在庫加算をトランザクション内で実行する" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_stock = inventory.stock

    # 無効なデータでは作成されず、在庫も変更されない
    assert_no_difference "AdditionalOrder.count" do
      assert_no_changes -> { inventory.reload.stock } do
        assert_raises ActiveRecord::RecordInvalid do
          AdditionalOrder.create_with_inventory!(
            location: locations(:city_hall),
            catalog: catalogs(:daily_bento_a),
            order_date: Date.current,
            order_time: Time.current,
            quantity: 0  # 無効な値
          )
        end
      end
    end
  end

  test "create! では在庫が加算されない" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_stock = inventory.stock

    AdditionalOrder.create!(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_date: Date.current,
      order_time: Time.current,
      quantity: 5
    )

    inventory.reload
    assert_equal initial_stock, inventory.stock
  end
end
