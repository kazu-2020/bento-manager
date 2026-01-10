require "test_helper"

class RefundTest < ActiveSupport::TestCase
  fixtures :locations, :employees, :catalogs, :catalog_prices, :daily_inventories, :sales, :sale_items

  # ===== Task 11.1: Refund モデル作成 =====

  test "valid refund" do
    original_sale = sales(:completed_sale)
    refund = Refund.new(
      original_sale: original_sale,
      refund_datetime: Time.current,
      amount: 500,
      reason: "商品の返品"
    )

    assert refund.valid?, refund.errors.full_messages.join(", ")
  end

  test "belongs_to original_sale" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      refund_datetime: Time.current,
      amount: 500,
      reason: "商品の返品"
    )

    assert_respond_to refund, :original_sale
    assert_equal sales(:completed_sale), refund.original_sale
  end

  test "belongs_to corrected_sale (optional)" do
    # 部分返金の場合：corrected_sale が存在する
    corrected_sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 200,
      final_amount: 200
    )

    refund = Refund.new(
      original_sale: sales(:completed_sale),
      corrected_sale: corrected_sale,
      refund_datetime: Time.current,
      amount: 300,
      reason: "部分返品"
    )

    assert refund.valid?
    assert_equal corrected_sale, refund.corrected_sale
  end

  test "corrected_sale is optional (full refund case)" do
    # 全額返金の場合：corrected_sale は nil
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      corrected_sale: nil,
      refund_datetime: Time.current,
      amount: 500,
      reason: "全額返金"
    )

    assert refund.valid?, "corrected_sale が nil でも valid であるべき"
  end

  test "belongs_to employee (optional)" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      employee: employees(:verified_employee),
      refund_datetime: Time.current,
      amount: 500,
      reason: "商品の返品"
    )

    assert refund.valid?
    assert_equal employees(:verified_employee), refund.employee
  end

  test "employee is optional" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      employee: nil,
      refund_datetime: Time.current,
      amount: 500,
      reason: "商品の返品"
    )

    assert refund.valid?, "employee が nil でも valid であるべき"
  end

  # ===== Task 11.2: Refund バリデーション実装 =====

  test "original_sale is required" do
    refund = Refund.new(
      original_sale: nil,
      refund_datetime: Time.current,
      amount: 500,
      reason: "商品の返品"
    )

    assert_not refund.valid?
    assert_includes refund.errors[:original_sale], "を入力してください"
  end

  test "refund_datetime is required" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      refund_datetime: nil,
      amount: 500,
      reason: "商品の返品"
    )

    assert_not refund.valid?
    assert_includes refund.errors[:refund_datetime], "を入力してください"
  end

  test "amount is required" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      refund_datetime: Time.current,
      amount: nil,
      reason: "商品の返品"
    )

    assert_not refund.valid?
    assert_includes refund.errors[:amount], "を入力してください"
  end

  test "amount must be greater than or equal to 0" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      refund_datetime: Time.current,
      amount: -1,
      reason: "商品の返品"
    )

    assert_not refund.valid?
    assert_includes refund.errors[:amount], "は0以上の値にしてください"
  end

  test "amount of 0 is valid" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      refund_datetime: Time.current,
      amount: 0,
      reason: "金額変更なし"
    )

    assert refund.valid?, "amount が 0 でも valid であるべき"
  end

  test "reason is required" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      refund_datetime: Time.current,
      amount: 500,
      reason: nil
    )

    assert_not refund.valid?
    assert_includes refund.errors[:reason], "を入力してください"
  end

  test "reason cannot be blank" do
    refund = Refund.new(
      original_sale: sales(:completed_sale),
      refund_datetime: Time.current,
      amount: 500,
      reason: ""
    )

    assert_not refund.valid?
    assert_includes refund.errors[:reason], "を入力してください"
  end

  # ===== アソシエーションテスト（逆方向） =====

  test "Sale has_many refunds as original_sale" do
    sale = sales(:completed_sale)
    refund = Refund.create!(
      original_sale: sale,
      refund_datetime: Time.current,
      amount: 100,
      reason: "テスト返金"
    )

    assert_includes sale.refunds, refund
  end

  test "Employee has_many refunds" do
    employee = employees(:verified_employee)
    refund = Refund.create!(
      original_sale: sales(:completed_sale),
      employee: employee,
      refund_datetime: Time.current,
      amount: 100,
      reason: "テスト返金"
    )

    assert_includes employee.refunds, refund
  end
end
