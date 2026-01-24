# frozen_string_literal: true

require "test_helper"

class CatalogPricesControllerTest < ActionDispatch::IntegrationTest
  fixtures :admins, :employees, :catalogs, :catalog_prices

  setup do
    @admin = admins(:verified_admin)
    @employee = employees(:verified_employee)
    @catalog = catalogs(:daily_bento_a)
    @catalog_price = catalog_prices(:daily_bento_a_regular)
    @catalog_without_bundle = catalogs(:daily_bento_b)
  end

  # ============================================================
  # Admin認証時のテスト
  # ============================================================

  test "admin can access edit for existing price" do
    login_as(@admin)
    get edit_catalog_catalog_price_path(@catalog, :regular), as: :turbo_stream
    assert_response :success
  end

  test "admin can access edit for non-existing price" do
    login_as(@admin)
    get edit_catalog_catalog_price_path(@catalog_without_bundle, :bundle), as: :turbo_stream
    assert_response :success
  end

  test "admin can create new price via update" do
    login_as(@admin)
    assert_difference("CatalogPrice.count") do
      patch catalog_catalog_price_path(@catalog_without_bundle, :bundle), params: {
        catalog_price: { price: 100 }
      }, as: :turbo_stream
    end
    assert_response :success
  end

  test "admin can update existing price (creates new record and closes old)" do
    login_as(@admin)
    original_count = CatalogPrice.count

    patch catalog_catalog_price_path(@catalog, :regular), params: {
      catalog_price: { price: 600 }
    }, as: :turbo_stream

    assert_response :success
    assert_equal original_count + 1, CatalogPrice.count

    @catalog_price.reload
    assert_not_nil @catalog_price.effective_until

    new_price = @catalog.price_by_kind(:regular)
    assert_equal 600, new_price.price
    assert_nil new_price.effective_until
  end

  # ============================================================
  # Employee認証時のテスト
  # ============================================================

  test "employee can access edit" do
    login_as_employee(@employee)
    get edit_catalog_catalog_price_path(@catalog, :regular), as: :turbo_stream
    assert_response :success
  end

  test "employee can create new price via update" do
    login_as_employee(@employee)
    assert_difference("CatalogPrice.count") do
      patch catalog_catalog_price_path(@catalog_without_bundle, :bundle), params: {
        catalog_price: { price: 100 }
      }, as: :turbo_stream
    end
    assert_response :success
  end

  test "employee can update existing price" do
    login_as_employee(@employee)
    patch catalog_catalog_price_path(@catalog, :regular), params: {
      catalog_price: { price: 580 }
    }, as: :turbo_stream

    assert_response :success

    new_price = @catalog.price_by_kind(:regular)
    assert_equal 580, new_price.price
  end

  # ============================================================
  # 未認証時のテスト
  # ============================================================

  test "unauthenticated user is redirected to login on edit" do
    get edit_catalog_catalog_price_path(@catalog, :regular), as: :turbo_stream
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on update" do
    original_price = @catalog_price.price
    patch catalog_catalog_price_path(@catalog, :regular), params: {
      catalog_price: { price: 999 }
    }, as: :turbo_stream
    assert_redirected_to "/employee/login"
    @catalog_price.reload
    assert_equal original_price, @catalog_price.price
  end

  # ============================================================
  # 無効なkindパラメータのテスト
  # ============================================================

  test "returns not found for invalid kind on edit" do
    login_as(@admin)
    get edit_catalog_catalog_price_path(@catalog, :invalid), as: :turbo_stream
    assert_response :not_found
  end

  test "returns not found for invalid kind on update" do
    login_as(@admin)
    patch catalog_catalog_price_path(@catalog, :invalid), params: {
      catalog_price: { price: 500 }
    }, as: :turbo_stream
    assert_response :not_found
  end

  # ============================================================
  # バリデーションエラーのテスト
  # ============================================================

  test "update with invalid price for new record renders form with unprocessable_entity" do
    login_as(@admin)
    assert_no_difference("CatalogPrice.count") do
      patch catalog_catalog_price_path(@catalog_without_bundle, :bundle), params: {
        catalog_price: { price: 0 }
      }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
  end

  test "update with invalid price for existing record renders form with unprocessable_entity" do
    login_as(@admin)
    original_count = CatalogPrice.count

    patch catalog_catalog_price_path(@catalog, :regular), params: {
      catalog_price: { price: -100 }
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_equal original_count, CatalogPrice.count
    @catalog_price.reload
    assert_nil @catalog_price.effective_until
  end
end
