require "test_helper"

class CouponTest < ActiveSupport::TestCase
  # ===== バリデーションテスト =====

  test "description は必須" do
    coupon = Coupon.new(description: nil, amount_per_unit: 50, max_per_bento_quantity: 1)
    assert_not coupon.valid?
    assert_includes coupon.errors[:description], "を入力してください"
  end

  test "amount_per_unit は必須" do
    coupon = Coupon.new(description: "テストクーポン", amount_per_unit: nil, max_per_bento_quantity: 1)
    assert_not coupon.valid?
    assert_includes coupon.errors[:amount_per_unit], "を入力してください"
  end

  test "amount_per_unit は0より大きい必要がある" do
    coupon = Coupon.new(description: "テストクーポン", amount_per_unit: 0, max_per_bento_quantity: 1)
    assert_not coupon.valid?
    assert_includes coupon.errors[:amount_per_unit], "は0より大きい値にしてください"
  end

  test "amount_per_unit は負数不可" do
    coupon = Coupon.new(description: "テストクーポン", amount_per_unit: -50, max_per_bento_quantity: 1)
    assert_not coupon.valid?
    assert_includes coupon.errors[:amount_per_unit], "は0より大きい値にしてください"
  end

  test "max_per_bento_quantity は必須" do
    coupon = Coupon.new(description: "テストクーポン", amount_per_unit: 50, max_per_bento_quantity: nil)
    assert_not coupon.valid?
    assert_includes coupon.errors[:max_per_bento_quantity], "を入力してください"
  end

  test "max_per_bento_quantity は0以上" do
    coupon = Coupon.new(description: "テストクーポン", amount_per_unit: 50, max_per_bento_quantity: 0)
    assert coupon.valid?, "max_per_bento_quantity が0でも有効: #{coupon.errors.full_messages.join(', ')}"
  end

  test "max_per_bento_quantity は負数不可" do
    coupon = Coupon.new(description: "テストクーポン", amount_per_unit: 50, max_per_bento_quantity: -1)
    assert_not coupon.valid?
    assert_includes coupon.errors[:max_per_bento_quantity], "は0以上の値にしてください"
  end

  test "有効な属性で作成できる" do
    coupon = Coupon.new(description: "50円割引クーポン", amount_per_unit: 50, max_per_bento_quantity: 1)
    assert coupon.valid?, "有効な属性で Coupon を作成できるべき: #{coupon.errors.full_messages.join(', ')}"
  end

  # ===== アソシエーションテスト =====

  test "discount との関連が正しく設定されている" do
    coupon = Coupon.create!(description: "関連テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
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

  test "max_applicable_quantity は弁当の合計個数 × max_per_bento_quantity を返す" do
    coupon = coupons(:fifty_yen_coupon)  # max_per_bento_quantity: 1
    bento_a = catalogs(:daily_bento_a)
    bento_b = catalogs(:daily_bento_b)

    sale_items = [
      { catalog: bento_a, quantity: 2 },
      { catalog: bento_b, quantity: 1 }
    ]

    # Requirement 13.2, 13.8: 弁当の種類数ではなく、個数ベースでカウント
    # 弁当の合計個数（2 + 1 = 3個）× max_per_bento_quantity(1) = 3
    assert_equal 3, coupon.max_applicable_quantity(sale_items)
  end

  test "max_applicable_quantity は弁当がない場合 0 を返す" do
    coupon = coupons(:fifty_yen_coupon)
    salad = catalogs(:salad)

    sale_items = [
      { catalog: salad, quantity: 2 }
    ]

    assert_equal 0, coupon.max_applicable_quantity(sale_items)
  end

  # ===== ビジネスロジック: calculate_discount テスト =====

  test "calculate_discount は max_applicable_quantity × amount_per_unit を返す" do
    coupon = coupons(:fifty_yen_coupon)  # amount_per_unit: 50, max_per_bento_quantity: 1
    bento = catalogs(:daily_bento_a)

    sale_items = [
      { catalog: bento, quantity: 2 }
    ]

    # Requirement 13.2, 13.8: 弁当の個数ベースでカウント
    # 弁当2個 × max_per_bento_quantity(1) = 2枚 × 50円 = 100円
    assert_equal 100, coupon.calculate_discount(sale_items)
  end

  test "calculate_discount は弁当がない場合 0 を返す" do
    coupon = coupons(:fifty_yen_coupon)
    salad = catalogs(:salad)

    sale_items = [
      { catalog: salad, quantity: 2 }
    ]

    assert_equal 0, coupon.calculate_discount(sale_items)
  end
end
