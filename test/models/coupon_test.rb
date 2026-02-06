require "test_helper"

class CouponTest < ActiveSupport::TestCase
  fixtures :coupons, :catalogs, :discounts

  test "validations" do
    @subject = Coupon.new(amount_per_unit: 50)

    must validate_presence_of(:amount_per_unit)
    must validate_numericality_of(:amount_per_unit).is_greater_than(0)
  end

  test "associations" do
    @subject = Coupon.new

    must have_one(:discount)
  end

  test "クーポンは弁当が含まれる場合のみ適用可能である" do
    coupon = coupons(:fifty_yen_coupon)
    bento = catalogs(:daily_bento_a)
    salad = catalogs(:salad)

    assert coupon.applicable?([ { catalog: bento, quantity: 1 } ])
    assert_not coupon.applicable?([ { catalog: salad, quantity: 2 } ])
    assert_not coupon.applicable?([])
  end

  test "クーポン適用上限は弁当の合計個数で決まる" do
    coupon = coupons(:fifty_yen_coupon)
    bento_a = catalogs(:daily_bento_a)
    bento_b = catalogs(:daily_bento_b)
    salad = catalogs(:salad)

    sale_items = [
      { catalog: bento_a, quantity: 3 },
      { catalog: bento_b, quantity: 2 }
    ]

    assert_equal 5, coupon.max_applicable_quantity(sale_items)
    assert_equal 0, coupon.max_applicable_quantity([ { catalog: salad, quantity: 2 } ])
    assert_equal 0, coupon.max_applicable_quantity([])
  end

  test "割引額はクーポン1枚あたりの固定額である" do
    coupon = coupons(:fifty_yen_coupon)
    bento = catalogs(:daily_bento_a)

    assert_equal 50, coupon.calculate_discount([ { catalog: bento, quantity: 2 } ])
  end
end
