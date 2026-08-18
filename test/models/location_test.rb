require "test_helper"

class LocationTest < ActiveSupport::TestCase
  include SaleTestHelper

  fixtures :locations, :catalogs, :daily_inventories, :employees

  test "validations" do
    @subject = Location.new(name: "テスト拠点")

    must validate_uniqueness_of(:name).case_insensitive
    must validate_presence_of(:name)
    must define_enum_for(:status).with_values(active: 0, inactive: 1).validating
  end

  test "associations" do
    @subject = Location.new

    must have_many(:daily_inventories).dependent(:restrict_with_error)
    must have_many(:sales).dependent(:restrict_with_error)
    must have_many(:additional_orders).dependent(:restrict_with_error)
  end

  test "販売先一覧は稼働中を先に表示し、同じ状態では名前の昇順で並ぶ" do
    inactive_b = Location.create!(name: "B販売先", status: :inactive)
    active_b = Location.create!(name: "B拠点", status: :active)
    inactive_a = Location.create!(name: "A販売先", status: :inactive)
    active_a = Location.create!(name: "A拠点", status: :active)

    test_ids = [ inactive_b.id, active_b.id, inactive_a.id, active_a.id ]
    ordered_ids = Location.display_order.where(id: test_ids).ids

    # active が先（A拠点, B拠点）、inactive が後（A販売先, B販売先）の name 順
    assert_equal [ active_a.id, active_b.id, inactive_a.id, inactive_b.id ], ordered_ids
  end

  # 当日在庫の絞り込み
  test "販売先の当日在庫には今日の日付のデータだけが含まれる" do
    city_hall = locations(:city_hall)
    today_inventories = city_hall.today_inventories

    assert_equal 3, today_inventories.size
    assert_not_includes today_inventories, daily_inventories(:city_hall_bento_a_yesterday)
  end

  test "在庫データが未登録の販売先の当日在庫は空である" do
    location = Location.create!(name: "新規販売先", status: :active)

    assert_empty location.today_inventories
  end

  # 当日在庫の有無判定
  test "当日の在庫がある販売先は在庫ありと判定される" do
    city_hall = locations(:city_hall)

    assert_predicate city_hall, :has_today_inventory?
  end

  test "当日の在庫がない販売先は在庫なしと判定される" do
    location = Location.create!(name: "在庫なし販売先", status: :active)

    assert_not location.has_today_inventory?
  end

  test "過去の在庫しかない販売先は在庫なしと判定される" do
    location = Location.create!(name: "昨日のみ販売先", status: :active)
    DailyInventory.create!(
      location: location,
      catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current - 1.day,
      stock: 5,
      reserved_stock: 0
    )

    assert_not location.has_today_inventory?
  end

  test "当日の販売がある販売先は販売開始済みと判定される" do
    location = Location.create!(name: "販売開始済み販売先", status: :active)
    create_sale(location: location, customer_type: :staff, sale_datetime: Time.current)

    assert_predicate location, :sales_started_today?
  end

  test "追加発注しかない販売先は販売未開始と判定される" do
    location = Location.create!(name: "追加発注のみ販売先", status: :active)
    DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current, stock: 20, reserved_stock: 0
    )
    AdditionalOrder.create_with_inventory!(
      location: location, catalog_id: catalogs(:daily_bento_a).id,
      quantity: 5, order_at: Time.current
    )

    assert_not_predicate location, :sales_started_today?
  end

  test "当日の追加発注を商品ごとに合計して返す" do
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

    quantities = location.today_additional_order_quantities

    assert_equal [ catalogs(:daily_bento_a), catalogs(:salad) ], quantities.keys
    assert_equal 8, quantities[catalogs(:daily_bento_a)]
    assert_equal 2, quantities[catalogs(:salad)]
  end

  test "前日の追加発注は当日の集計に含めない" do
    location = Location.create!(name: "前日追加発注販売先", status: :active)
    DailyInventory.create!(
      location: location, catalog: catalogs(:daily_bento_a),
      inventory_date: Date.current - 1.day, stock: 20, reserved_stock: 0
    )
    AdditionalOrder.create_with_inventory!(
      location: location, catalog_id: catalogs(:daily_bento_a).id,
      quantity: 5, order_at: 1.day.ago
    )

    assert_empty location.today_additional_order_quantities
  end

  test "販売終了した商品への追加発注は集計に含めない" do
    location = Location.create!(name: "販売終了商品発注販売先", status: :active)
    catalog = Catalog.create!(name: "終了予定弁当", kana: "シュウリョウヨテイベントウ", category: :bento)
    DailyInventory.create!(
      location: location, catalog: catalog,
      inventory_date: Date.current, stock: 10, reserved_stock: 0
    )
    AdditionalOrder.create_with_inventory!(
      location: location, catalog_id: catalog.id, quantity: 5, order_at: Time.current
    )
    CatalogDiscontinuation.create!(
      catalog: catalog, discontinued_at: Time.current, reason: "提供終了"
    )

    assert_empty location.today_additional_order_quantities
  end

  test "追加発注がなければ空を返す" do
    location = Location.create!(name: "追加発注なし販売先", status: :active)

    assert_empty location.today_additional_order_quantities
  end
end
