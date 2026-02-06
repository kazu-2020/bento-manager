require "test_helper"

class SaleTest < ActiveSupport::TestCase
  fixtures :locations, :employees

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
    must belong_to(:corrected_from_sale).class_name("Sale").optional
    must have_one(:correction_sale).class_name("Sale")
    must have_many(:items).class_name("SaleItem").dependent(:destroy)
    must have_many(:sale_discounts).dependent(:destroy)
    must have_many(:discounts).through(:sale_discounts)
    must have_many(:refunds).dependent(:restrict_with_error)
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
    assert completed_sale.valid?
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

    freeze_time do
      sale.void!(voided_by: employees(:verified_employee))
      sale.reload

      assert sale.voided?
      assert_equal Time.current, sale.voided_at
      assert_equal employees(:verified_employee), sale.voided_by_employee
    end

    assert_raises(Sale::AlreadyVoidedError) do
      sale.void!(voided_by: employees(:verified_employee))
    end
  end
end
