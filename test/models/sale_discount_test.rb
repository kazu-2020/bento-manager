require "test_helper"

class SaleDiscountTest < ActiveSupport::TestCase
  fixtures :locations, :employees, :catalogs, :catalog_prices,
           :daily_inventories, :sales, :coupons, :discounts, :sale_discounts

  # ===== Task 9.1: アソシエーションテスト =====

  test "belongs to sale" do
    sale_discount = sale_discounts(:completed_sale_fifty_yen)
    assert_instance_of Sale, sale_discount.sale
    assert_equal sales(:completed_sale), sale_discount.sale
  end

  test "belongs to discount" do
    sale_discount = sale_discounts(:completed_sale_fifty_yen)
    assert_instance_of Discount, sale_discount.discount
    assert_equal discounts(:fifty_yen_discount), sale_discount.discount
  end

  test "sale has_many sale_discounts" do
    sale = sales(:completed_sale)
    assert_includes sale.sale_discounts, sale_discounts(:completed_sale_fifty_yen)
  end

  test "discount has_many sale_discounts" do
    discount = discounts(:fifty_yen_discount)
    assert_includes discount.sale_discounts, sale_discounts(:completed_sale_fifty_yen)
  end

  # ===== Task 9.2: バリデーションテスト =====

  test "sale must be present" do
    sale_discount = build_valid_sale_discount
    sale_discount.sale = nil
    assert_not sale_discount.valid?
    assert_includes sale_discount.errors[:sale], "を入力してください"
  end

  test "discount must be present" do
    sale_discount = build_valid_sale_discount
    sale_discount.discount = nil
    assert_not sale_discount.valid?
    assert_includes sale_discount.errors[:discount], "を入力してください"
  end

  test "discount_amount must be present" do
    sale_discount = build_valid_sale_discount
    sale_discount.discount_amount = nil
    assert_not sale_discount.valid?
    assert_includes sale_discount.errors[:discount_amount], "を入力してください"
  end

  test "discount_amount must be greater than or equal to 0" do
    sale_discount = build_valid_sale_discount

    # 0 は有効
    sale_discount.discount_amount = 0
    assert sale_discount.valid?

    # 負の値は無効
    sale_discount.discount_amount = -1
    assert_not sale_discount.valid?
    assert_includes sale_discount.errors[:discount_amount], "は0以上の値にしてください"
  end

  # ===== Task 9.2: ユニーク制約テスト（同じ割引の重複適用防止） =====

  test "discount_id must be unique scoped to sale_id" do
    existing = sale_discounts(:completed_sale_fifty_yen)

    duplicate = SaleDiscount.new(
      sale: existing.sale,
      discount: existing.discount,
      discount_amount: 50
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:discount_id], "同じ割引を複数回適用できません"
  end

  test "same discount can be applied to different sales" do
    # 同じ割引を異なる販売に適用することは可能
    sale_discount = SaleDiscount.new(
      sale: sales(:prefectural_office_sale),
      discount: discounts(:fifty_yen_discount),
      discount_amount: 50
    )

    assert sale_discount.valid?
  end

  private

  def build_valid_sale_discount
    # voided_sale を使用（既存フィクスチャとの重複を避けるため）
    SaleDiscount.new(
      sale: sales(:voided_sale),
      discount: discounts(:hundred_yen_discount),
      discount_amount: 100
    )
  end
end
