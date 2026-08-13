require "test_helper"

# DB レベルの CHECK 制約と外部キーの削除時挙動を検証する。
#
# モデルのバリデーションを迂回した書き込み（update_column / delete_all 等）でも
# 台帳が壊れないことを保証するためのテストなので、意図的にバリデーションを
# 通さない経路で書き込んでいる。
class SchemaConstraintsTest < ActiveSupport::TestCase
  fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items,
           :daily_inventories, :coupons, :discounts, :sale_discounts, :catalog_pricing_rules

  # Rodauth 管理のテーブル群。AR モデルを持たないため直接 SQL で操作する。
  # 値は id 以外の必須カラムとその埋め込み値。
  RODAUTH_TABLES = {
    employee_lockouts: { key: "lockout-key", deadline: "2099-01-01 00:00:00" },
    employee_login_failures: { number: 1 },
    employee_remember_keys: { key: "remember-token", deadline: "2099-01-01 00:00:00" }
  }.freeze

  # ============================================================
  # CHECK 制約
  # ============================================================

  test "販売明細の数量・単価・小計にゼロ以下は保存できない" do
    item = sale_items(:completed_sale_bento_a)

    assert_raises(ActiveRecord::StatementInvalid) { item.update_column(:quantity, 0) }
    assert_raises(ActiveRecord::StatementInvalid) { item.update_column(:unit_price, 0) }

    # line_total は attr_readonly で update_column が AR 層で弾かれるため、
    # それも迂回する update_all で DB 側の制約に到達させる
    assert_raises(ActiveRecord::StatementInvalid) do
      SaleItem.where(id: item.id).update_all(line_total: -1)
    end
  end

  test "販売の小計と合計はゼロを許すが負の金額は保存できない" do
    sale = sales(:completed_sale)

    assert_changes -> { sale.reload.final_amount }, to: 0 do
      sale.update_column(:total_amount, 0)
      sale.update_column(:final_amount, 0)
    end

    assert_raises(ActiveRecord::StatementInvalid) { sale.update_column(:total_amount, -1) }
    assert_raises(ActiveRecord::StatementInvalid) { sale.update_column(:final_amount, -1) }
  end

  test "当日在庫の在庫数と引当数に負の数は保存できない" do
    inventory = daily_inventories(:city_hall_bento_a_today)

    assert_raises(ActiveRecord::StatementInvalid) { inventory.update_column(:stock, -1) }
    assert_raises(ActiveRecord::StatementInvalid) { inventory.update_column(:reserved_stock, -1) }
  end

  test "カタログ価格にゼロ以下は保存できない" do
    price = catalog_prices(:daily_bento_a_regular)

    assert_raises(ActiveRecord::StatementInvalid) { price.update_column(:price, 0) }
  end

  test "適用済み割引の割引額と枚数にゼロ以下は保存できない" do
    sale_discount = sale_discounts(:completed_sale_fifty_yen)

    assert_raises(ActiveRecord::StatementInvalid) { sale_discount.update_column(:discount_amount, 0) }
    assert_raises(ActiveRecord::StatementInvalid) { sale_discount.update_column(:quantity, 0) }
  end

  test "追加発注の数量にゼロ以下は保存できない" do
    order = AdditionalOrder.create!(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_at: Time.current,
      quantity: 5
    )

    assert_raises(ActiveRecord::StatementInvalid) { order.update_column(:quantity, 0) }
  end

  test "クーポンの一枚あたり割引額にゼロ以下は保存できない" do
    coupon = coupons(:fifty_yen_coupon)

    assert_raises(ActiveRecord::StatementInvalid) { coupon.update_column(:amount_per_unit, 0) }
  end

  test "価格ルールの最大適用数に負の数は保存できない" do
    rule = catalog_pricing_rules(:salad_bundle_by_bento)

    assert_raises(ActiveRecord::StatementInvalid) { rule.update_column(:max_per_trigger, -1) }
  end

  test "返金の差額には負の値を保存できる" do
    refund = Refund.create!(
      original_sale: sales(:completed_sale),
      employee: employees(:owner_employee),
      refund_datetime: Time.current,
      amount: -300
    )

    assert_equal(-300, refund.reload.amount, "返品時の追加徴収は負の差額として記録される")
  end

  # ============================================================
  # 外部キーの削除時挙動
  # ============================================================

  test "従業員を物理削除すると販売の担当者と取消担当者が空になる" do
    sale = sales(:voided_sale)
    salesperson = sale.employee
    voider = sale.voided_by_employee

    Employee.where(id: [ salesperson.id, voider.id ]).delete_all

    sale.reload

    assert_nil sale.employee_id, "担当者が退職しても販売記録そのものは残る"
    assert_nil sale.voided_by_employee_id
  end

  test "従業員を物理削除すると認証の付属情報も削除される" do
    employee = employees(:verified_employee)
    RODAUTH_TABLES.each_key { |table| insert_rodauth_row(table, employee) }

    counts = RODAUTH_TABLES.keys.map { |table| -> { rodauth_row_count(table, employee) } }

    assert_difference counts, -1 do
      Employee.where(id: employee.id).delete_all
    end
  end

  test "販売実績がある販売先は物理削除できない" do
    location = locations(:city_hall)

    assert_raises(ActiveRecord::StatementInvalid) { Location.where(id: location.id).delete_all }
  end

  test "訂正元として参照されている販売は物理削除できない" do
    original = sales(:completed_sale)
    Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 400,
      final_amount: 400,
      corrected_from_sale: original
    )

    assert_raises(ActiveRecord::StatementInvalid) { Sale.where(id: original.id).delete_all }
  end

  private

  def insert_rodauth_row(table, employee)
    columns = RODAUTH_TABLES.fetch(table)
    names = [ "id", *columns.keys ].join(", ")
    placeholders = Array.new(columns.size + 1, "?").join(", ")

    connection.execute(
      sanitize("INSERT INTO #{table} (#{names}) VALUES (#{placeholders})", employee.id, *columns.values)
    )
  end

  def rodauth_row_count(table, employee)
    connection.select_value(
      sanitize("SELECT COUNT(*) FROM #{table} WHERE id = ?", employee.id)
    )
  end

  def connection
    ActiveRecord::Base.connection
  end

  def sanitize(sql, *binds)
    ActiveRecord::Base.sanitize_sql_array([ sql, *binds ])
  end
end
