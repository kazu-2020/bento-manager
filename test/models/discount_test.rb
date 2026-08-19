require "test_helper"

class DiscountTest < ActiveSupport::TestCase
  fixtures :coupons, :catalogs, :discounts

  test "validations" do
    @subject = Discount.new(
      discountable: Coupon.create!(amount_per_unit: 50),
      name: "テスト割引",
      valid_from: Date.current
    )

    must validate_presence_of(:name)
    must validate_presence_of(:valid_from)
  end

  test "割引の状態は有効期間と当日の関係で期間前・有効・期限切れに分かれる" do
    upcoming = Discount.new(name: "来週から", valid_from: Date.current + 1)
    active_without_end = Discount.new(name: "無期限", valid_from: Date.current)
    active_within_period = Discount.new(name: "期間中", valid_from: Date.current - 1, valid_until: Date.current)
    expired = Discount.new(name: "終了済み", valid_from: Date.current - 2, valid_until: Date.current - 1)

    assert_equal :upcoming, upcoming.status
    assert_equal :active, active_without_end.status
    assert_equal :active, active_within_period.status
    assert_equal :expired, expired.status
  end

  test "associations" do
    @subject = Discount.new

    must belong_to(:discountable)
    must have_many(:sale_discounts).dependent(:restrict_with_exception)
    must have_many(:sales).through(:sale_discounts)
  end

  test "有効期間の終了日は開始日以降でなければならず、同じ日なら1日だけ有効な割引になる" do
    coupon = Coupon.create!(amount_per_unit: 50)
    today = Date.current

    before_start = Discount.new(discountable: coupon, name: "テスト", valid_from: today, valid_until: 1.day.ago.to_date)

    assert_not before_start.valid?
    assert_includes before_start.errors[:valid_until], "は有効開始日以降の日付を指定してください"

    same_day = Discount.create!(discountable: coupon, name: "テスト", valid_from: today, valid_until: today)

    assert_includes Discount.active_at(today), same_day
    assert_not_includes Discount.active_at(today + 1), same_day

    after_start = Discount.new(discountable: coupon, name: "テスト", valid_from: today, valid_until: 1.day.from_now.to_date)

    assert_predicate after_start, :valid?

    no_end = Discount.new(discountable: coupon, name: "テスト", valid_from: today, valid_until: nil)

    assert_predicate no_end, :valid?
  end

  test "有効な割引のみが取得される" do
    coupon1 = Coupon.create!(amount_per_unit: 50)
    coupon2 = Coupon.create!(amount_per_unit: 50)
    coupon3 = Coupon.create!(amount_per_unit: 50)
    coupon4 = Coupon.create!(amount_per_unit: 50)

    active = Discount.create!(discountable: coupon1, name: "有効", valid_from: 1.week.ago.to_date)
    with_end = Discount.create!(discountable: coupon4, name: "期間内", valid_from: 1.week.ago.to_date, valid_until: 1.week.from_now.to_date)
    expired = Discount.create!(discountable: coupon2, name: "期限切れ", valid_from: 1.month.ago.to_date, valid_until: 1.day.ago.to_date)
    future = Discount.create!(discountable: coupon3, name: "未来", valid_from: 1.week.from_now.to_date)

    result = Discount.active

    assert_includes result, active
    assert_includes result, with_end
    assert_not_includes result, expired
    assert_not_includes result, future
  end

  test "割引額は弁当が含まれる場合のみ適用される" do
    coupon = Coupon.create!(amount_per_unit: 50)
    discount = Discount.create!(discountable: coupon, name: "テスト割引", valid_from: Date.current)
    bento = catalogs(:daily_bento_a)
    salad = catalogs(:salad)

    assert_equal 50, discount.calculate_discount([ { catalog: bento, quantity: 2 } ])
    assert_equal 0, discount.calculate_discount([ { catalog: salad, quantity: 2 } ])
  end
end
