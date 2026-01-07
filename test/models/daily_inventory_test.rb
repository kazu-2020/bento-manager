require "test_helper"

class DailyInventoryTest < ActiveSupport::TestCase
  fixtures :locations, :catalogs, :daily_inventories

  # =============================================================================
  # Task 6.1: モデル存在・アソシエーションテスト
  # =============================================================================

  test "有効な属性で作成できる" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day,
      stock: 10,
      reserved_stock: 0
    )
    assert inventory.valid?
  end

  test "location との関連が正しく設定されている" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    assert_equal locations(:city_hall), inventory.location
  end

  test "catalog との関連が正しく設定されている" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    assert_equal catalogs(:daily_bento_a), inventory.catalog
  end

  # =============================================================================
  # Task 6.3: ユニーク制約テスト
  # =============================================================================

  test "location_id, catalog_id, inventory_date の組み合わせはユニーク" do
    existing = daily_inventories(:city_hall_bento_a_today)
    duplicate = DailyInventory.new(
      location: existing.location,
      catalog: existing.catalog,
      inventory_date: existing.inventory_date,
      stock: 5,
      reserved_stock: 0
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:inventory_date], "同じ販売先・商品・日付の組み合わせは既に存在します"
  end

  test "同じ location と catalog でも異なる日付であれば作成可能" do
    existing = daily_inventories(:city_hall_bento_a_today)
    new_inventory = DailyInventory.new(
      location: existing.location,
      catalog: existing.catalog,
      inventory_date: existing.inventory_date + 1.day,
      stock: 5,
      reserved_stock: 0
    )
    assert new_inventory.valid?
  end

  test "同じ location と日付でも異なる catalog であれば作成可能" do
    existing = daily_inventories(:city_hall_bento_a_today)
    new_inventory = DailyInventory.new(
      location: existing.location,
      catalog: catalogs(:miso_soup),
      inventory_date: existing.inventory_date,
      stock: 5,
      reserved_stock: 0
    )
    assert new_inventory.valid?
  end

  # =============================================================================
  # Task 6.2: バリデーションテスト
  # =============================================================================

  test "location は必須" do
    inventory = DailyInventory.new(
      location: nil,
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day,
      stock: 10,
      reserved_stock: 0
    )
    assert_not inventory.valid?
    assert_includes inventory.errors[:location], "を入力してください"
  end

  test "catalog は必須" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: nil,
      inventory_date: Date.current + 1.day,
      stock: 10,
      reserved_stock: 0
    )
    assert_not inventory.valid?
    assert_includes inventory.errors[:catalog], "を入力してください"
  end

  test "inventory_date は必須" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: nil,
      stock: 10,
      reserved_stock: 0
    )
    assert_not inventory.valid?
    assert_includes inventory.errors[:inventory_date], "を入力してください"
  end

  test "stock は0以上である必要がある" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day,
      stock: -1,
      reserved_stock: 0
    )
    assert_not inventory.valid?
    assert_includes inventory.errors[:stock], "は0以上の値にしてください"
  end

  test "stock が0は有効" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day,
      stock: 0,
      reserved_stock: 0
    )
    assert inventory.valid?
  end

  test "reserved_stock は0以上である必要がある" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day,
      stock: 10,
      reserved_stock: -1
    )
    assert_not inventory.valid?
    assert_includes inventory.errors[:reserved_stock], "は0以上の値にしてください"
  end

  test "reserved_stock が0は有効" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day,
      stock: 10,
      reserved_stock: 0
    )
    assert inventory.valid?
  end

  test "available_stock (stock - reserved_stock) は0以上である必要がある" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day,
      stock: 5,
      reserved_stock: 10
    )
    assert_not inventory.valid?
    assert_includes inventory.errors[:base], "利用可能在庫数（stock - reserved_stock）は0以上である必要があります"
  end

  test "available_stock が0は有効" do
    inventory = DailyInventory.new(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current + 1.day,
      stock: 5,
      reserved_stock: 5
    )
    assert inventory.valid?
  end

  test "available_stock メソッドが正しく計算する" do
    inventory = daily_inventories(:city_hall_bento_b_today)
    # stock: 5, reserved_stock: 2
    assert_equal 3, inventory.available_stock
  end

  # =============================================================================
  # Task 6.4: 在庫操作メソッドテスト
  # =============================================================================

  # --- decrement_stock! ---

  test "decrement_stock! で在庫を減算できる" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_stock = inventory.stock
    quantity = 3

    inventory.decrement_stock!(quantity)
    inventory.reload

    assert_equal initial_stock - quantity, inventory.stock
  end

  test "decrement_stock! で在庫不足時はエラーを発生させる" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    # stock: 10

    error = assert_raises(DailyInventory::InsufficientStockError) do
      inventory.decrement_stock!(15)
    end
    assert_match(/在庫が不足しています/, error.message)
  end

  test "decrement_stock! で0以下の数量はエラーを発生させる" do
    inventory = daily_inventories(:city_hall_bento_a_today)

    assert_raises(ArgumentError) do
      inventory.decrement_stock!(0)
    end

    assert_raises(ArgumentError) do
      inventory.decrement_stock!(-1)
    end
  end

  test "decrement_stock! でぴったり在庫を減らせる" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    # stock: 10
    inventory.decrement_stock!(10)
    inventory.reload

    assert_equal 0, inventory.stock
  end

  # --- increment_stock! ---

  test "increment_stock! で在庫を加算できる" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_stock = inventory.stock
    quantity = 5

    inventory.increment_stock!(quantity)
    inventory.reload

    assert_equal initial_stock + quantity, inventory.stock
  end

  test "increment_stock! で0以下の数量はエラーを発生させる" do
    inventory = daily_inventories(:city_hall_bento_a_today)

    assert_raises(ArgumentError) do
      inventory.increment_stock!(0)
    end

    assert_raises(ArgumentError) do
      inventory.increment_stock!(-1)
    end
  end

  # --- 楽観的ロックテスト ---

  test "decrement_stock! は楽観的ロックを使用する" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_lock_version = inventory.lock_version

    inventory.decrement_stock!(1)
    inventory.reload

    assert_equal initial_lock_version + 1, inventory.lock_version
  end

  test "increment_stock! は楽観的ロックを使用する" do
    inventory = daily_inventories(:city_hall_bento_a_today)
    initial_lock_version = inventory.lock_version

    inventory.increment_stock!(1)
    inventory.reload

    assert_equal initial_lock_version + 1, inventory.lock_version
  end
end
