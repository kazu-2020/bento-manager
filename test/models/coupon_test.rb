require "test_helper"

class CouponTest < ActiveSupport::TestCase
  fixtures :coupons, :catalogs, :discounts

  # ===== バリデーションテスト =====

  test "amount_per_unit は必須" do
    coupon = Coupon.new(amount_per_unit: nil)
    assert_not coupon.valid?
    assert_includes coupon.errors[:amount_per_unit], "を入力してください"
  end

  test "amount_per_unit は0より大きい必要がある" do
    coupon = Coupon.new(amount_per_unit: 0)
    assert_not coupon.valid?
    assert_includes coupon.errors[:amount_per_unit], "は0より大きい値にしてください"
  end

  test "amount_per_unit は負数不可" do
    coupon = Coupon.new(amount_per_unit: -50)
    assert_not coupon.valid?
    assert_includes coupon.errors[:amount_per_unit], "は0より大きい値にしてください"
  end

  test "有効な属性で作成できる" do
    coupon = Coupon.new(amount_per_unit: 50)
    assert coupon.valid?, "有効な属性で Coupon を作成できるべき: #{coupon.errors.full_messages.join(', ')}"
  end

  # ===== アソシエーションテスト =====

  test "discount との関連が正しく設定されている" do
    coupon = Coupon.create!(amount_per_unit: 50)
    discount = Discount.create!(
      discountable: coupon,
      name: "テスト割引",
      valid_from: Date.current
    )

    # reload して関連を再取得
    coupon.reload
    assert_equal discount, coupon.discount
  end

  # ===== ビジネスロジック: applicable? テスト =====

  test "applicable? は弁当がある場合 true を返す" do
    coupon = coupons(:fifty_yen_coupon)
    bento = catalogs(:daily_bento_a)

    sale_items = [
      { catalog: bento, quantity: 1 }
    ]

    assert coupon.applicable?(sale_items)
  end

  test "applicable? は弁当がない場合 false を返す" do
    coupon = coupons(:fifty_yen_coupon)
    salad = catalogs(:salad)

    sale_items = [
      { catalog: salad, quantity: 2 }
    ]

    assert_not coupon.applicable?(sale_items)
  end

  test "applicable? は空の sale_items で false を返す" do
    coupon = coupons(:fifty_yen_coupon)
    assert_not coupon.applicable?([])
  end

  # ===== ビジネスロジック: max_applicable_quantity テスト =====

  test "max_applicable_quantity は弁当の合計個数を返す" do
    coupon = coupons(:fifty_yen_coupon)
    bento_a = catalogs(:daily_bento_a)
    bento_b = catalogs(:daily_bento_b)

    sale_items = [
      { catalog: bento_a, quantity: 3 },
      { catalog: bento_b, quantity: 2 }
    ]

    assert_equal 5, coupon.max_applicable_quantity(sale_items)
  end

  test "max_applicable_quantity は弁当がない場合0を返す" do
    coupon = coupons(:fifty_yen_coupon)
    salad = catalogs(:salad)

    sale_items = [
      { catalog: salad, quantity: 2 }
    ]

    assert_equal 0, coupon.max_applicable_quantity(sale_items)
  end

  test "max_applicable_quantity は空の sale_items で0を返す" do
    coupon = coupons(:fifty_yen_coupon)
    assert_equal 0, coupon.max_applicable_quantity([])
  end

  # ===== ビジネスロジック: calculate_discount テスト =====

  test "calculate_discount はクーポン1枚あたり固定額 amount_per_unit を返す" do
    coupon = coupons(:fifty_yen_coupon)  # amount_per_unit: 50
    bento = catalogs(:daily_bento_a)

    sale_items = [
      { catalog: bento, quantity: 2 }
    ]

    # クーポン1枚あたり固定50円（弁当個数に依存しない）
    assert_equal 50, coupon.calculate_discount(sale_items)
  end

  test "calculate_discount は弁当がなくても固定額 amount_per_unit を返す" do
    coupon = coupons(:fifty_yen_coupon)
    salad = catalogs(:salad)

    sale_items = [
      { catalog: salad, quantity: 2 }
    ]

    # Coupon は固定額を返す（applicable? チェックは Discount 側で行う）
    assert_equal 50, coupon.calculate_discount(sale_items)
  end
end
