require "test_helper"

class SaleTest < ActiveSupport::TestCase
  fixtures :locations, :employees

  # =============================================================================
  # Task 7.1: モデル存在・アソシエーション・Enumテスト
  # =============================================================================

  test "有効な属性で作成できる" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed,
      employee: employees(:verified_employee)
    )
    assert sale.valid?
  end

  test "location との関連が正しく設定されている" do
    sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed,
      employee: employees(:verified_employee)
    )
    assert_equal locations(:city_hall), sale.location
  end

  test "employee との関連が正しく設定されている" do
    sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed,
      employee: employees(:verified_employee)
    )
    assert_equal employees(:verified_employee), sale.employee
  end

  test "employee は任意" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed,
      employee: nil
    )
    assert sale.valid?
  end

  # --- status enum テスト ---

  test "status enum が completed を持つ" do
    sale = Sale.new(status: :completed)
    assert sale.completed?
    assert_not sale.voided?
  end

  test "status enum が voided を持つ" do
    sale = Sale.new(status: :voided)
    assert sale.voided?
    assert_not sale.completed?
  end

  test "無効な status はバリデーションエラーになる" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :invalid_status
    )
    assert_not sale.valid?
    assert_includes sale.errors[:status], "は一覧にありません"
  end

  # --- customer_type enum テスト ---

  test "customer_type enum が staff を持つ" do
    sale = Sale.new(customer_type: :staff)
    assert sale.staff?
    assert_not sale.citizen?
  end

  test "customer_type enum が citizen を持つ" do
    sale = Sale.new(customer_type: :citizen)
    assert sale.citizen?
    assert_not sale.staff?
  end

  test "無効な customer_type はバリデーションエラーになる" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :invalid_type,
      total_amount: 1000,
      final_amount: 950,
      status: :completed
    )
    assert_not sale.valid?
    assert_includes sale.errors[:customer_type], "は一覧にありません"
  end

  # --- corrected_from_sale 関連テスト ---

  test "corrected_from_sale との関連が正しく設定されている" do
    original_sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :voided,
      voided_at: Time.current,
      voided_by_employee: employees(:verified_employee),
      void_reason: "テスト返品"
    )

    corrected_sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 500,
      final_amount: 500,
      status: :completed,
      corrected_from_sale: original_sale
    )

    assert_equal original_sale, corrected_sale.corrected_from_sale
    assert_equal corrected_sale, original_sale.correction_sale
  end

  # =============================================================================
  # Task 7.2: バリデーションテスト
  # =============================================================================

  test "sale_datetime は必須" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: nil,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed
    )
    assert_not sale.valid?
    assert_includes sale.errors[:sale_datetime], "を入力してください"
  end

  test "customer_type は必須" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: nil,
      total_amount: 1000,
      final_amount: 950,
      status: :completed
    )
    assert_not sale.valid?
    assert_includes sale.errors[:customer_type], "を入力してください"
  end

  test "total_amount は必須" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: nil,
      final_amount: 950,
      status: :completed
    )
    assert_not sale.valid?
    assert_includes sale.errors[:total_amount], "を入力してください"
  end

  test "final_amount は必須" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: nil,
      status: :completed
    )
    assert_not sale.valid?
    assert_includes sale.errors[:final_amount], "を入力してください"
  end

  test "total_amount は0以上である必要がある" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: -1,
      final_amount: 950,
      status: :completed
    )
    assert_not sale.valid?
    assert_includes sale.errors[:total_amount], "は0以上の値にしてください"
  end

  test "total_amount が0は有効" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 0,
      final_amount: 0,
      status: :completed
    )
    assert sale.valid?
  end

  test "final_amount は0以上である必要がある" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: -1,
      status: :completed
    )
    assert_not sale.valid?
    assert_includes sale.errors[:final_amount], "は0以上の値にしてください"
  end

  test "final_amount が0は有効" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 0,
      status: :completed
    )
    assert sale.valid?
  end

  # --- status が voided の場合の必須バリデーション ---

  test "status が voided の場合、voided_at は必須" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :voided,
      voided_at: nil,
      voided_by_employee: employees(:verified_employee),
      void_reason: "テスト返品"
    )
    assert_not sale.valid?
    assert_includes sale.errors[:voided_at], "を入力してください"
  end

  test "status が voided の場合、voided_by_employee は必須" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :voided,
      voided_at: Time.current,
      voided_by_employee: nil,
      void_reason: "テスト返品"
    )
    assert_not sale.valid?
    assert_includes sale.errors[:voided_by_employee], "を入力してください"
  end

  test "status が voided の場合、void_reason は必須" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :voided,
      voided_at: Time.current,
      voided_by_employee: employees(:verified_employee),
      void_reason: nil
    )
    assert_not sale.valid?
    assert_includes sale.errors[:void_reason], "を入力してください"
  end

  test "status が completed の場合、voided フィールドは任意" do
    sale = Sale.new(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed,
      voided_at: nil,
      voided_by_employee: nil,
      void_reason: nil
    )
    assert sale.valid?
  end

  # =============================================================================
  # Task 7.4: void メソッドテスト
  # =============================================================================

  test "void! で status を voided に変更できる" do
    sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed
    )

    sale.void!(
      reason: "商品間違い",
      voided_by: employees(:verified_employee)
    )

    sale.reload
    assert sale.voided?
    assert_not_nil sale.voided_at
    assert_equal employees(:verified_employee), sale.voided_by_employee
    assert_equal "商品間違い", sale.void_reason
  end

  test "void! で voided_at が記録される" do
    sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :completed
    )

    freeze_time do
      sale.void!(
        reason: "商品間違い",
        voided_by: employees(:verified_employee)
      )
      sale.reload

      assert_equal Time.current, sale.voided_at
    end
  end

  test "voided? は status が voided の場合に true を返す" do
    sale = Sale.new(status: :voided)
    assert sale.voided?
  end

  test "voided? は status が completed の場合に false を返す" do
    sale = Sale.new(status: :completed)
    assert_not sale.voided?
  end

  test "既に voided の Sale に void! を呼ぶとエラーになる" do
    sale = Sale.create!(
      location: locations(:city_hall),
      sale_datetime: Time.current,
      customer_type: :staff,
      total_amount: 1000,
      final_amount: 950,
      status: :voided,
      voided_at: Time.current,
      voided_by_employee: employees(:verified_employee),
      void_reason: "初回の取消"
    )

    error = assert_raises(Sale::AlreadyVoidedError) do
      sale.void!(
        reason: "再度の取消",
        voided_by: employees(:verified_employee)
      )
    end
    assert_match(/既に取り消されています/, error.message)
  end
end
