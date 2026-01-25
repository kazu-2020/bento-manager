# frozen_string_literal: true

require "test_helper"

class DiscountsControllerTest < ActionDispatch::IntegrationTest
  fixtures :admins, :employees, :discounts, :coupons

  setup do
    @admin = admins(:verified_admin)
    @employee = employees(:verified_employee)
    @discount = discounts(:fifty_yen_discount)
    @expired_discount = discounts(:expired_discount)
  end

  # ============================================================
  # Admin認証時のテスト（アクセス可能）
  # ============================================================

  test "admin can access index" do
    login_as(@admin)
    get discounts_path
    assert_response :success
  end

  test "admin can access show" do
    login_as(@admin)
    get discount_path(@discount)
    assert_response :success
  end

  test "admin can access new" do
    login_as(@admin)
    get new_discount_path, as: :turbo_stream
    assert_response :success
  end

  test "admin can create discount" do
    login_as(@admin)
    assert_difference("Discount.count") do
      assert_difference("Coupon.count") do
        post discounts_path, params: {
          discount: {
            name: "新規クーポン",
            valid_from: Date.current,
            valid_until: 1.month.from_now.to_date,
            discountable_attributes: {
              description: "テストクーポン",
              amount_per_unit: 50,
              max_per_bento_quantity: 1
            }
          }
        }, as: :turbo_stream
      end
    end
    assert_response :success
  end

  test "admin can access edit for basic_info" do
    login_as(@admin)
    get edit_discount_path(@discount, section: :basic_info)
    assert_response :success
  end

  test "admin can access edit for coupon_info" do
    login_as(@admin)
    get edit_discount_path(@discount, section: :coupon_info)
    assert_response :success
  end

  test "admin can update discount basic_info" do
    login_as(@admin)
    patch discount_path(@discount, section: :basic_info), params: {
      discount: { name: "更新されたクーポン名" }
    }, as: :turbo_stream
    assert_response :success
    @discount.reload
    assert_equal "更新されたクーポン名", @discount.name
  end

  test "admin can update discount coupon_info" do
    login_as(@admin)
    patch discount_path(@discount, section: :coupon_info), params: {
      discount: {
        discountable_attributes: {
          id: @discount.discountable.id,
          description: "更新された説明",
          amount_per_unit: 100,
          max_per_bento_quantity: 2
        }
      }
    }, as: :turbo_stream
    assert_response :success
    @discount.discountable.reload
    assert_equal "更新された説明", @discount.discountable.description
    assert_equal 100, @discount.discountable.amount_per_unit
    assert_equal 2, @discount.discountable.max_per_bento_quantity
  end

  # ============================================================
  # Employee認証時のテスト（アクセス可能）
  # ============================================================

  test "employee can access index" do
    login_as_employee(@employee)
    get discounts_path
    assert_response :success
  end

  test "employee can access show" do
    login_as_employee(@employee)
    get discount_path(@discount)
    assert_response :success
  end

  test "employee can access new" do
    login_as_employee(@employee)
    get new_discount_path, as: :turbo_stream
    assert_response :success
  end

  test "employee can create discount" do
    login_as_employee(@employee)
    assert_difference("Discount.count") do
      assert_difference("Coupon.count") do
        post discounts_path, params: {
          discount: {
            name: "従業員作成クーポン",
            valid_from: Date.current,
            discountable_attributes: {
              description: "従業員が作成",
              amount_per_unit: 30,
              max_per_bento_quantity: 1
            }
          }
        }, as: :turbo_stream
      end
    end
    assert_response :success
  end

  test "employee can access edit" do
    login_as_employee(@employee)
    get edit_discount_path(@discount, section: :basic_info)
    assert_response :success
  end

  test "employee can update discount" do
    login_as_employee(@employee)
    patch discount_path(@discount, section: :basic_info), params: {
      discount: { name: "従業員更新クーポン名" }
    }, as: :turbo_stream
    assert_response :success
    @discount.reload
    assert_equal "従業員更新クーポン名", @discount.name
  end

  # ============================================================
  # 未認証時のテスト（ログインページにリダイレクト）
  # ============================================================

  test "unauthenticated user is redirected to login on index" do
    get discounts_path
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on show" do
    get discount_path(@discount)
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on new" do
    get new_discount_path
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on create" do
    assert_no_difference("Discount.count") do
      post discounts_path, params: {
        discount: {
          name: "不正なクーポン",
          valid_from: Date.current
        }
      }
    end
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on edit" do
    get edit_discount_path(@discount, section: :basic_info)
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on update" do
    patch discount_path(@discount), params: {
      discount: { name: "不正な更新" }
    }
    assert_redirected_to "/employee/login"
  end

  # ============================================================
  # バリデーションエラー時のレスポンステスト
  # ============================================================

  test "create with blank name renders new with unprocessable_entity" do
    login_as(@admin)
    assert_no_difference("Discount.count") do
      post discounts_path, params: {
        discount: {
          name: "",
          valid_from: Date.current,
          discountable_attributes: {
            description: "テスト",
            amount_per_unit: 50,
            max_per_bento_quantity: 1
          }
        }
      }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
  end

  test "update with invalid params renders edit with unprocessable_entity" do
    login_as(@admin)
    original_name = @discount.name
    patch discount_path(@discount, section: :basic_info), params: {
      discount: { name: "" }
    }, as: :turbo_stream
    assert_response :unprocessable_entity
    @discount.reload
    assert_equal original_name, @discount.name
  end
end
