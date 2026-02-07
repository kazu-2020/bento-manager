require "test_helper"

class DailyInventoryTest < ActiveSupport::TestCase
  fixtures :locations, :catalogs, :daily_inventories

  test "validations" do
    @subject = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 100.days,
      stock: 10,
      reserved_stock: 0
    )

    must validate_presence_of(:inventory_date)
    must validate_presence_of(:stock)
    must validate_numericality_of(:stock).is_greater_than_or_equal_to(0)
    must validate_presence_of(:reserved_stock)
    must validate_numericality_of(:reserved_stock).is_greater_than_or_equal_to(0)
    must validate_uniqueness_of(:inventory_date).scoped_to(:location_id, :catalog_id)
      .with_message("同じ販売先・商品・日付の組み合わせは既に存在します")
  end

  test "associations" do
    @subject = DailyInventory.new

    must belong_to(:location)
    must belong_to(:catalog)
  end

  test "利用可能在庫数は総在庫から予約在庫を引いた値であり負数は許可されない" do
    inventory = daily_inventories(:city_hall_bento_b_today)
    assert_equal 3, inventory.available_stock  # stock: 5, reserved_stock: 2

    over_reserved = DailyInventory.new(
      location: locations(:city_hall), catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day, stock: 5, reserved_stock: 10
    )
    assert_not over_reserved.valid?
    assert_includes over_reserved.errors[:base], "利用可能在庫数（stock - reserved_stock）は0以上である必要があります"

    exactly_zero = DailyInventory.new(
      location: locations(:city_hall), catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 2.days, stock: 5, reserved_stock: 5
    )
    assert exactly_zero.valid?
  end

  test "在庫から販売数を減算できる" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_stock = inventory.stock
    initial_lock_version = inventory.lock_version

    inventory.decrement_stock!(3)
    inventory.reload

    assert_equal initial_stock - 3, inventory.stock
    assert_equal initial_lock_version + 1, inventory.lock_version

    inventory.decrement_stock!(inventory.stock)
    inventory.reload
    assert_equal 0, inventory.stock

    assert_raises(DailyInventory::InsufficientStockError) { inventory.decrement_stock!(1) }
    assert_raises(ArgumentError) { inventory.decrement_stock!(0) }
    assert_raises(ArgumentError) { inventory.decrement_stock!(-1) }
  end

  test "在庫に返品・追加発注分を加算できる" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_stock = inventory.stock
    initial_lock_version = inventory.lock_version

    inventory.increment_stock!(5)
    inventory.reload

    assert_equal initial_stock + 5, inventory.stock
    assert_equal initial_lock_version + 1, inventory.lock_version

    assert_raises(ArgumentError) { inventory.increment_stock!(0) }
    assert_raises(ArgumentError) { inventory.increment_stock!(-1) }
  end

  test "一括登録で当日の在庫を作成できる" do
    location = Location.create!(name: "一括作成テスト販売先", status: :active)
    items = [
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_a).id, stock: 10),
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_b).id, stock: 5)
    ]

    assert_difference "DailyInventory.count", 2 do
      result = DailyInventory.bulk_create(location: location, items: items)
      assert_equal 2, result
    end

    last_two = DailyInventory.last(2)
    last_two.each do |inv|
      assert_equal Date.current, inv.inventory_date
      assert_equal 0, inv.reserved_stock
    end
  end

  test "在庫操作が未発生の場合は販売未開始と判定される" do
    location = Location.create!(name: "販売開始判定テスト", status: :active)
    DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current, stock: 10, reserved_stock: 0
    )

    assert_not DailyInventory.sales_started?(location: location)
  end

  test "在庫操作が発生済みの場合は販売開始済みと判定される" do
    location = Location.create!(name: "販売開始済み判定テスト", status: :active)
    inventory = DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current, stock: 10, reserved_stock: 0
    )
    inventory.decrement_stock!(1)

    assert DailyInventory.sales_started?(location: location)
  end

  test "登録済みの在庫を削除してから再作成できる" do
    location = Location.create!(name: "再登録テスト", status: :active)
    DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current, stock: 10, reserved_stock: 0
    )

    items = [
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_a).id, stock: 20),
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_b).id, stock: 5)
    ]

    assert_difference "DailyInventory.count", 1 do
      result = DailyInventory.bulk_recreate(location: location, items: items)
      assert_equal 2, result
    end

    recreated = DailyInventory.where(location: location, inventory_date: Date.current)
    assert_equal 2, recreated.count
    assert_equal 20, recreated.find_by(catalog: catalogs(:daily_bento_a)).stock
  end

  test "販売が開始された在庫は再登録できない" do
    location = Location.create!(name: "販売開始後再登録テスト", status: :active)
    inventory = DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current, stock: 10, reserved_stock: 0
    )
    inventory.decrement_stock!(1)

    items = [
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_a).id, stock: 20)
    ]

    assert_no_difference "DailyInventory.count" do
      result = DailyInventory.bulk_recreate(location: location, items: items)
      assert_equal :sales_already_started, result
    end
  end

  test "再登録で商品の追加・削除ができる" do
    location = Location.create!(name: "商品変更テスト", status: :active)
    DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current, stock: 10, reserved_stock: 0
    )
    DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_b),
      inventory_date: Date.current, stock: 5, reserved_stock: 0
    )

    items = [
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_b).id, stock: 8),
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:salad).id, stock: 15)
    ]

    result = DailyInventory.bulk_recreate(location: location, items: items)
    assert_equal 2, result

    remaining = DailyInventory.where(location: location, inventory_date: Date.current)
    assert_equal 2, remaining.count
    assert_nil remaining.find_by(catalog: catalogs(:daily_bento_a))
    assert_equal 8, remaining.find_by(catalog: catalogs(:daily_bento_b)).stock
    assert_equal 15, remaining.find_by(catalog: catalogs(:salad)).stock
  end

  test "再登録後も lock_version は 0 で再度修正できる" do
    location = Location.create!(name: "lock_versionテスト", status: :active)
    DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current, stock: 10, reserved_stock: 0
    )

    items = [
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_a).id, stock: 20)
    ]

    DailyInventory.bulk_recreate(location: location, items: items)

    recreated = DailyInventory.find_by(location: location, catalog: catalogs(:daily_bento_a), inventory_date: Date.current)
    assert_equal 0, recreated.lock_version
    assert_not DailyInventory.sales_started?(location: location)
  end

  test "一括登録で1件でも不正なデータがあれば全件登録されない" do
    location = Location.create!(name: "ロールバックテスト販売先", status: :active)
    DailyInventory.create!(
      location: location,
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current,
      stock: 5,
      reserved_stock: 0
    )

    items = [
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_b).id, stock: 10),
      DailyInventories::InventoryItem.new(catalog_id: catalogs(:daily_bento_a).id, stock: 15)
    ]

    assert_no_difference "DailyInventory.count" do
      result = DailyInventory.bulk_create(location: location, items: items)
      assert_equal 0, result
    end
  end
end
