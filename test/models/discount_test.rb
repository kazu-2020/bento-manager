require "test_helper"

class DiscountTest < ActiveSupport::TestCase
  fixtures :coupons, :catalogs, :discounts

  # ===== バリデーションテスト =====

  test "name は必須" do
    coupon = coupons(:fifty_yen_coupon)
    discount = Discount.new(discountable: coupon, name: nil, valid_from: Date.current)
    assert_not discount.valid?
    assert_includes discount.errors[:name], "を入力してください"
  end

  test "valid_from は必須" do
    coupon = coupons(:fifty_yen_coupon)
    discount = Discount.new(discountable: coupon, name: "テスト割引", valid_from: nil)
    assert_not discount.valid?
    assert_includes discount.errors[:valid_from], "を入力してください"
  end

  test "valid_until は nullable" do
    coupon = Coupon.create!(description: "nullable テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.new(discountable: coupon, name: "テスト割引", valid_from: Date.current, valid_until: nil)
    assert discount.valid?, "valid_until が nil でも有効: #{discount.errors.full_messages.join(', ')}"
  end

  test "有効な属性で作成できる" do
    coupon = Coupon.create!(description: "作成テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.new(
      discountable: coupon,
      name: "50円割引クーポン",
      valid_from: Date.current,
      valid_until: 1.month.from_now.to_date
    )
    assert discount.valid?, "有効な属性で Discount を作成できるべき: #{discount.errors.full_messages.join(', ')}"
  end

  # ===== 日付範囲バリデーションテスト（Task 5.3） =====

  test "valid_until が valid_from より前の場合はエラー" do
    coupon = Coupon.create!(description: "日付範囲テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.new(
      discountable: coupon,
      name: "テスト割引",
      valid_from: Date.current,
      valid_until: 1.day.ago.to_date
    )
    assert_not discount.valid?
    assert_includes discount.errors[:valid_until], "は有効開始日より後の日付を指定してください"
  end

  test "valid_until が valid_from と同じ場合はエラー" do
    coupon = Coupon.create!(description: "同日テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    today = Date.current
    discount = Discount.new(
      discountable: coupon,
      name: "テスト割引",
      valid_from: today,
      valid_until: today
    )
    assert_not discount.valid?
    assert_includes discount.errors[:valid_until], "は有効開始日より後の日付を指定してください"
  end

  test "valid_until が valid_from より後の場合は有効" do
    coupon = Coupon.create!(description: "有効日付テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.new(
      discountable: coupon,
      name: "テスト割引",
      valid_from: Date.current,
      valid_until: 1.day.from_now.to_date
    )
    assert discount.valid?, "valid_until > valid_from は有効: #{discount.errors.full_messages.join(', ')}"
  end

  # ===== Delegated Type テスト =====

  test "delegated_type が Coupon を受け入れる" do
    coupon = Coupon.create!(description: "delegated_type テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.create!(
      discountable: coupon,
      name: "クーポン割引",
      valid_from: Date.current
    )

    assert_equal "Coupon", discount.discountable_type
    assert_equal coupon.id, discount.discountable_id
    assert_equal coupon, discount.discountable
  end

  test "coupon? メソッドが使用可能" do
    coupon = Coupon.create!(description: "coupon? テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.create!(
      discountable: coupon,
      name: "クーポン割引",
      valid_from: Date.current
    )

    assert discount.coupon?
  end

  # ===== スコープテスト =====

  test "active スコープは現在有効な割引のみ取得" do
    coupon1 = Coupon.create!(description: "有効クーポン", amount_per_unit: 50, max_per_bento_quantity: 1)
    coupon2 = Coupon.create!(description: "期限切れクーポン", amount_per_unit: 50, max_per_bento_quantity: 1)
    coupon3 = Coupon.create!(description: "未来のクーポン", amount_per_unit: 50, max_per_bento_quantity: 1)

    # 現在有効（valid_until なし）
    active_discount = Discount.create!(
      discountable: coupon1,
      name: "有効割引",
      valid_from: 1.week.ago.to_date,
      valid_until: nil
    )

    # 期限切れ
    expired_discount = Discount.create!(
      discountable: coupon2,
      name: "期限切れ割引",
      valid_from: 1.month.ago.to_date,
      valid_until: 1.day.ago.to_date
    )

    # 未来の開始日
    future_discount = Discount.create!(
      discountable: coupon3,
      name: "未来の割引",
      valid_from: 1.week.from_now.to_date,
      valid_until: nil
    )

    active_discounts = Discount.active

    assert_includes active_discounts, active_discount
    assert_not_includes active_discounts, expired_discount
    assert_not_includes active_discounts, future_discount
  end

  test "active スコープは valid_until が今日以降の割引を含む" do
    coupon = Coupon.create!(description: "期間内クーポン", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.create!(
      discountable: coupon,
      name: "期間内割引",
      valid_from: 1.week.ago.to_date,
      valid_until: 1.week.from_now.to_date
    )

    assert_includes Discount.active, discount
  end

  # ===== 委譲メソッドテスト =====

  test "applicable? は discountable に委譲される" do
    coupon = Coupon.create!(description: "委譲テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.create!(
      discountable: coupon,
      name: "委譲テスト割引",
      valid_from: Date.current
    )
    bento = catalogs(:daily_bento_a)

    sale_items = [ { catalog: bento, quantity: 1 } ]

    assert discount.applicable?(sale_items)
  end

  test "calculate_discount は discountable に委譲される" do
    coupon = Coupon.create!(description: "計算委譲テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.create!(
      discountable: coupon,
      name: "計算委譲テスト割引",
      valid_from: Date.current
    )
    bento = catalogs(:daily_bento_a)

    sale_items = [ { catalog: bento, quantity: 2 } ]

    # Requirement 13.2, 13.8: 弁当の個数ベースでカウント
    # 弁当2個 × max_per_bento_quantity(1) = 2枚 × 50円 = 100円
    assert_equal 100, discount.calculate_discount(sale_items)
  end

  test "calculate_discount は applicable? が false の場合 0 を返す" do
    coupon = Coupon.create!(description: "非適用テスト", amount_per_unit: 50, max_per_bento_quantity: 1)
    discount = Discount.create!(
      discountable: coupon,
      name: "非適用テスト割引",
      valid_from: Date.current
    )
    salad = catalogs(:salad)

    sale_items = [ { catalog: salad, quantity: 2 } ]

    assert_equal 0, discount.calculate_discount(sale_items)
  end
end
