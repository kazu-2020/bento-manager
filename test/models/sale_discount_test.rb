require "test_helper"

class SaleDiscountTest < ActiveSupport::TestCase
  fixtures :locations, :employees, :sales, :discounts, :sale_discounts

  test "validations" do
    @subject = SaleDiscount.new(
      sale: sales(:voided_sale),
      discount: discounts(:hundred_yen_discount),
      discount_amount: 100,
      quantity: 1
    )

    must validate_uniqueness_of(:discount_id).scoped_to(:sale_id).with_message("同じ割引を複数回適用できません")
    must validate_presence_of(:discount_amount)
    must validate_numericality_of(:discount_amount).is_greater_than(0)
    must validate_presence_of(:quantity)
    must validate_numericality_of(:quantity).is_greater_than(0)
  end

  test "associations" do
    @subject = SaleDiscount.new

    must belong_to(:sale)
    must belong_to(:discount)
  end

  test "同じ割引は異なる販売には適用できるが同一販売への重複適用はできない" do
    existing = sale_discounts(:completed_sale_fifty_yen)

    duplicate = SaleDiscount.new(sale: existing.sale, discount: existing.discount, discount_amount: 50, quantity: 1)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:discount_id], "同じ割引を複数回適用できません"

    different_sale = SaleDiscount.new(sale: sales(:prefectural_office_sale), discount: existing.discount, discount_amount: 50, quantity: 1)
    assert different_sale.valid?
  end
end
