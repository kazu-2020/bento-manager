require "test_helper"

# DB レベルの CHECK 制約と外部キーの削除時挙動を検証する。
#
# モデルのバリデーションを迂回した書き込みでも台帳が壊れないことを保証するのが目的なので、
# 書き込みには一貫して update_all を使う。update_column は attr_readonly を尊重するため
# AR 層で止まってしまい、DB の制約に到達しない。
class SchemaConstraintsTest < ActiveSupport::TestCase
  include SaleTestHelper

  fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items,
           :daily_inventories, :coupons, :discounts, :sale_discounts, :catalog_pricing_rules

  # Rodauth 管理のテーブル群。id 以外の必須カラムと、そこに入れる値。
  #
  # これらを fixture にしてはならない。fixture はプロセス全体で生存するため、
  # 同一ワーカー内の他テストにも認証状態が漏れる。実際 employee_lockouts を
  # fixture 化したところ verified_employee がロックアウト扱いになり、
  # 認証を伴うテストが軒並みログインに失敗した。
  # テスト内で挿入すればテストごとのトランザクションで巻き戻る。
  RODAUTH_ROWS = {
    employee_lockouts: { key: "lockout-key", deadline: "2099-01-01 00:00:00" },
    employee_login_failures: { number: 1 },
    employee_remember_keys: { key: "remember-token", deadline: "2099-01-01 00:00:00" }
  }.freeze

  # ============================================================
  # CHECK 制約
  # ============================================================

  test "販売明細の数量・単価・小計にゼロ以下は保存できない" do
    item = sale_items(:completed_sale_bento_a)

    assert_db_rejects item, quantity: 0
    assert_db_rejects item, unit_price: 0
    assert_db_rejects item, line_total: -1
  end

  test "販売の小計と合計はゼロを許すが負の金額は保存できない" do
    sale = sales(:completed_sale)

    assert_changes -> { sale.reload.final_amount }, to: 0 do
      Sale.where(id: sale.id).update_all(total_amount: 0, final_amount: 0)
    end

    assert_db_rejects sale, total_amount: -1
    assert_db_rejects sale, final_amount: -1
  end

  test "当日在庫の在庫数と引当数に負の数は保存できない" do
    inventory = daily_inventories(:city_hall_bento_a_today)

    assert_db_rejects inventory, stock: -1
    assert_db_rejects inventory, reserved_stock: -1
  end

  test "カタログ価格にゼロ以下は保存できない" do
    assert_db_rejects catalog_prices(:daily_bento_a_regular), price: 0
  end

  test "適用済み割引の割引額と枚数にゼロ以下は保存できない" do
    sale_discount = sale_discounts(:completed_sale_fifty_yen)

    assert_db_rejects sale_discount, discount_amount: 0
    assert_db_rejects sale_discount, quantity: 0
  end

  test "追加発注の数量にゼロ以下は保存できない" do
    order = AdditionalOrder.create!(
      location: locations(:city_hall),
      catalog: catalogs(:daily_bento_a),
      order_at: Time.current,
      quantity: 5
    )

    assert_db_rejects order, quantity: 0
  end

  test "クーポンの一枚あたり割引額にゼロ以下は保存できない" do
    assert_db_rejects coupons(:fifty_yen_coupon), amount_per_unit: 0
  end

  test "価格ルールの最大適用数に負の数は保存できない" do
    assert_db_rejects catalog_pricing_rules(:salad_bundle_by_bento), max_per_trigger: -1
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

    Employee.where(id: [ sale.employee_id, sale.voided_by_employee_id ]).delete_all

    sale.reload

    assert_nil sale.employee_id, "担当者が退職しても販売記録そのものは残る"
    assert_nil sale.voided_by_employee_id
  end

  test "従業員を物理削除すると認証の付属情報も削除される" do
    employee = employees(:verified_employee)
    RODAUTH_ROWS.each_key { |table| insert_rodauth_row(table, employee) }

    counts = RODAUTH_ROWS.keys.map { |table| -> { rodauth_row_count(table, employee) } }

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
    create_sale(
      location: locations(:city_hall),
      customer_type: :staff,
      sale_datetime: Time.current,
      corrected_from_sale: original
    )

    assert_raises(ActiveRecord::StatementInvalid) { Sale.where(id: original.id).delete_all }
  end

  private

  # バリデーションも attr_readonly も迂回して DB へ直接書き込み、制約に弾かれることを確認する
  def assert_db_rejects(record, attributes)
    assert_raises(ActiveRecord::StatementInvalid) do
      record.class.where(id: record.id).update_all(attributes)
    end
  end

  # AR モデルを持たないテーブルなので、Rails の型変換込みの行挿入 API を直接使う
  def insert_rodauth_row(table, employee)
    ActiveRecord::Base.connection.insert_fixture(
      { "id" => employee.id, **RODAUTH_ROWS.fetch(table).stringify_keys }, table
    )
  end

  def rodauth_row_count(table, employee)
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array(
        [ "SELECT COUNT(*) FROM #{table} WHERE id = ?", employee.id ]
      )
    )
  end
end
