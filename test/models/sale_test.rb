require "test_helper"

class SaleTest < ActiveSupport::TestCase
  include SaleTestHelper

  fixtures :locations, :employees, :catalogs, :catalog_prices, :sales, :sale_items, :discounts

  test "validations" do
    @subject = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed
    )

    must validate_presence_of(:sale_datetime)
    must validate_presence_of(:customer_type)
    must validate_presence_of(:total_amount)
    must validate_numericality_of(:total_amount).is_greater_than_or_equal_to(0)
    must validate_presence_of(:final_amount)
    must validate_numericality_of(:final_amount).is_greater_than_or_equal_to(0)
    must define_enum_for(:status).with_values(completed: 0, voided: 1).validating
    must define_enum_for(:customer_type).with_values(staff: 0, citizen: 1).validating
  end

  test "associations" do
    @subject = Sale.new

    must belong_to(:location)
    must belong_to(:employee).optional
    must belong_to(:voided_by_employee).class_name("Employee").optional
    must have_many(:items).class_name("SaleItem").dependent(:destroy)
    must have_many(:sale_discounts).dependent(:destroy)
    must have_many(:discounts).through(:sale_discounts)
    must have_one(:refund).with_foreign_key("original_sale_id").dependent(:restrict_with_error)
  end

  test "取り消し時は取消日時と取消担当者が必須になる" do
    voided_sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :voided,
      voided_at: nil,
      voided_by_employee: nil
    )

    assert_not voided_sale.valid?
    assert_includes voided_sale.errors[:voided_at], "を入力してください"
    assert_includes voided_sale.errors[:voided_by_employee], "を入力してください"

    completed_sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed,
      voided_at: nil,
      voided_by_employee: nil
    )

    assert_predicate completed_sale, :valid?
  end

  # --- スコープテスト ---

  test "in_period は指定期間内の販売のみを返す" do
    period_start = 8.days.ago.beginning_of_day
    period_end = Time.current

    results = Sale.in_period(period_start, period_end)

    # 10日前の analysis_citizen_5 は含まれない
    assert_not_includes results, sales(:analysis_citizen_5)
    # 1日前の analysis_staff_1 は含まれる
    assert_includes results, sales(:analysis_staff_1)
  end

  test "at_location は指定の販売先の販売のみを返す" do
    results = Sale.at_location(locations(:city_hall))

    assert_includes results, sales(:analysis_staff_1)
    assert_not_includes results, sales(:analysis_pref_1)
  end

  test "販売を取り消すと状態が変わり取消済みの販売は再度取り消せない" do
    sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed
    )
    # 取消前に読み込まれ、別のリクエストが持ち続けている古いインスタンス
    stale_sale = Sale.find(sale.id)

    freeze_time do
      sale.void!(voided_by: employees(:verified_employee))
      sale.reload

      assert_predicate sale, :voided?
      assert_equal Time.current, sale.voided_at
      assert_equal employees(:verified_employee), sale.voided_by_employee
    end

    assert_raises(Sale::AlreadyVoidedError) do
      sale.void!(voided_by: employees(:verified_employee))
    end

    # 古いインスタンスの voided? は false のままだが、取消の可否は DB で判定される
    assert_raises(Sale::AlreadyVoidedError) do
      stale_sale.void!(voided_by: employees(:owner_employee))
    end

    assert_equal employees(:verified_employee), sale.reload.voided_by_employee
  end

  test "当日に確定した販売があれば販売開始済みと判定される" do
    location = Location.create!(name: "販売開始判定テスト", status: :active)
    create_sale(location: location, customer_type: :staff, sale_datetime: Time.current)

    assert Sale.started?(location: location)
  end

  test "当日の販売が取消済みだけでも販売開始済みと判定される" do
    location = Location.create!(name: "全額返金後判定テスト", status: :active)
    create_sale(
      location: location, customer_type: :staff, sale_datetime: Time.current,
      status: :voided, voided_at: Time.current, voided_by_employee: employees(:owner_employee)
    )

    assert Sale.started?(location: location)
  end

  test "当日の販売がなければ販売未開始と判定される" do
    location = Location.create!(name: "販売未開始判定テスト", status: :active)

    assert_not Sale.started?(location: location)
  end

  test "別の販売先の販売では販売開始済みと判定されない" do
    location = Location.create!(name: "他販売先判定テスト", status: :active)
    other_location = Location.create!(name: "他販売先判定テスト2", status: :active)
    create_sale(location: other_location, customer_type: :staff, sale_datetime: Time.current)

    assert_not Sale.started?(location: location)
  end

  test "前日の販売では当日の販売開始済みと判定されない" do
    location = Location.create!(name: "前日販売判定テスト", status: :active)
    create_sale(location: location, customer_type: :staff, sale_datetime: 1.day.ago)

    assert_not Sale.started?(location: location)
    assert Sale.started?(location: location, date: Date.current - 1.day)
  end

  test "深夜近くの販売でも当日の販売開始済みと判定される" do
    location = Location.create!(name: "深夜判定テスト", status: :active)

    travel_to Time.zone.parse("2026-08-18 23:30:00") do
      create_sale(location: location, customer_type: :staff, sale_datetime: Time.current)

      assert Sale.started?(location: location)
    end
  end

  test "日付をまたぐ深夜帯の販売も、その日の売上としてまとめて集計される" do
    location = Location.create!(name: "JST日付境界テスト", status: :active)
    # UTC 基準では 8/9 に落ちる 0:30 と、8/10 に残る 23:30。どちらも JST では 8/10
    create_sale(location: location, customer_type: :staff, sale_datetime: Time.zone.local(2026, 8, 10, 0, 30))
    create_sale(location: location, customer_type: :staff, sale_datetime: Time.zone.local(2026, 8, 10, 23, 30))

    assert_equal({ "2026-08-10" => 2 }, Sale.at_location(location).group(Sale.jst_date_expression).count)
  end

  test "差額精算できるのは、当日の販売のうちまだ取り消されていないものだけ" do
    today_sale = create_sale(location: locations(:city_hall), customer_type: :staff, sale_datetime: Time.current)
    yesterday_sale = create_sale(location: locations(:city_hall), customer_type: :staff, sale_datetime: 1.day.ago)
    voided_today_sale = create_sale(
      location: locations(:city_hall), customer_type: :staff, sale_datetime: Time.current,
      status: :voided, voided_at: Time.current, voided_by_employee: employees(:verified_employee)
    )

    assert_predicate today_sale, :refundable?
    assert_not_predicate yesterday_sale, :refundable?
    assert_not_predicate voided_today_sale, :refundable?

    # 日付が変われば、同じ販売が当日のものではなくなる
    travel_to(1.day.from_now) do
      assert_not_predicate today_sale, :refundable?
    end
  end

  test "販売に適用されたクーポンの割引 ID と枚数を返す" do
    sale = create_sale(location: locations(:city_hall), customer_type: :staff, sale_datetime: Time.current)
    fifty_yen = discounts(:fifty_yen_discount)
    hundred_yen = discounts(:hundred_yen_discount)
    SaleDiscount.create!(sale: sale, discount: fifty_yen, discount_amount: 100, quantity: 2)
    SaleDiscount.create!(sale: sale, discount: hundred_yen, discount_amount: 100, quantity: 1)

    assert_equal({ fifty_yen.id => 2, hundred_yen.id => 1 }, sale.applied_discount_quantities)

    # クーポンを使っていない販売は「0 枚」ではなく、そもそも枚数が無い
    no_coupon_sale = create_sale(location: locations(:city_hall), customer_type: :staff, sale_datetime: Time.current)

    assert_empty no_coupon_sale.applied_discount_quantities
  end
  # --- bento_quantity ---

  test "販売で売れた弁当の個数はサイドメニューを数えない" do
    sale = create_sale(location: locations(:city_hall), customer_type: :staff, sale_datetime: Time.current)
    create_sale_item(sale: sale, quantity: 2)
    create_sale_item(sale: sale, quantity: 3, catalog_price: catalog_prices(:salad_regular))

    assert_equal 2, sale.bento_quantity
  end

  test "サラダしか売れなかった販売の弁当の個数は0になる" do
    sale = create_sale(location: locations(:city_hall), customer_type: :citizen, sale_datetime: Time.current)
    create_sale_item(sale: sale, quantity: 1, catalog_price: catalog_prices(:salad_regular))

    assert_equal 0, sale.bento_quantity
  end
end
