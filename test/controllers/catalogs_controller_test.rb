# frozen_string_literal: true

require "test_helper"

class CatalogsControllerTest < ActionDispatch::IntegrationTest
  fixtures :employees, :catalogs

  setup do
    @employee = employees(:verified_employee)
    @catalog = catalogs(:daily_bento_a)
    @discontinued_catalog = catalogs(:discontinued_bento)
    @discontinued_catalog.create_discontinuation!(
      discontinued_at: Time.current,
      reason: "テスト用提供終了"
    )
  end

  # ============================================================
  # Admin認証時のテスト（アクセス可能）
  # ============================================================

  test "admin can access index" do
    login_as_employee(@employee)
    get catalogs_path
    assert_response :success
  end

  test "admin can access show" do
    login_as_employee(@employee)
    get catalog_path(@catalog)
    assert_response :success
  end

  test "admin can access new" do
    login_as_employee(@employee)
    get new_catalog_path, as: :turbo_stream
    assert_response :success
  end

  test "admin can create catalog" do
    login_as_employee(@employee)
    assert_difference("Catalog.count") do
      assert_difference("CatalogPrice.count") do
        post catalogs_path, params: {
          catalog: {
            name: "新規弁当",
            category: "bento",
            description: "新商品の説明",
            regular_price: 450
          }
        }, as: :turbo_stream
      end
    end
    assert_response :success
  end

  test "admin can access edit" do
    login_as_employee(@employee)
    get edit_catalog_path(@catalog)
    assert_response :success
  end

  test "admin can update catalog" do
    login_as_employee(@employee)
    patch catalog_path(@catalog), params: {
      catalog: { name: "更新された弁当名" }
    }, as: :turbo_stream
    assert_response :success
    @catalog.reload
    assert_equal "更新された弁当名", @catalog.name
  end

  # ============================================================
  # Employee認証時のテスト（アクセス可能）
  # ============================================================

  test "employee can access index" do
    login_as_employee(@employee)
    get catalogs_path
    assert_response :success
  end

  test "employee can access show" do
    login_as_employee(@employee)
    get catalog_path(@catalog)
    assert_response :success
  end

  test "employee can access new" do
    login_as_employee(@employee)
    get new_catalog_path, as: :turbo_stream
    assert_response :success
  end

  test "employee can create catalog" do
    login_as_employee(@employee)
    assert_difference("Catalog.count") do
      assert_difference("CatalogPrice.count") do
        post catalogs_path, params: {
          catalog: {
            name: "従業員作成弁当",
            category: "bento",
            description: "従業員が作成",
            regular_price: 400
          }
        }, as: :turbo_stream
      end
    end
    assert_response :success
  end

  test "employee can access edit" do
    login_as_employee(@employee)
    get edit_catalog_path(@catalog)
    assert_response :success
  end

  test "employee can update catalog" do
    login_as_employee(@employee)
    patch catalog_path(@catalog), params: {
      catalog: { name: "従業員更新弁当名" }
    }, as: :turbo_stream
    assert_response :success
    @catalog.reload
    assert_equal "従業員更新弁当名", @catalog.name
  end

  # ============================================================
  # 未認証時のテスト（ログインページにリダイレクト）
  # ============================================================

  test "unauthenticated user is redirected to login on index" do
    get catalogs_path
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on show" do
    get catalog_path(@catalog)
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on new" do
    get new_catalog_path
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on create" do
    assert_no_difference("Catalog.count") do
      post catalogs_path, params: {
        catalog: {
          name: "不正な弁当",
          category: "bento"
        }
      }
    end
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on edit" do
    get edit_catalog_path(@catalog)
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on update" do
    patch catalog_path(@catalog), params: {
      catalog: { name: "不正な更新" }
    }
    assert_redirected_to "/employee/login"
  end

  # ============================================================
  # バリデーションエラー時のレスポンステスト
  # ※バリデーションロジック自体のテストはモデルテストで担保
  # ============================================================

  test "create with blank name renders new with unprocessable_entity" do
    login_as_employee(@employee)
    assert_no_difference("Catalog.count") do
      post catalogs_path, params: { catalog: { name: "", category: "bento", regular_price: 450 } }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
  end

  test "update with invalid params renders edit with unprocessable_entity" do
    login_as_employee(@employee)
    original_name = @catalog.name
    patch catalog_path(@catalog), params: { catalog: { name: "" } }, as: :turbo_stream
    assert_response :unprocessable_entity
    @catalog.reload
    assert_equal original_name, @catalog.name
  end

  # ============================================================
  # 不正カテゴリのテスト
  # ============================================================

  test "new with invalid category returns unprocessable_entity" do
    login_as_employee(@employee)
    get new_catalog_path, params: { category: "invalid_category" }
    assert_response :unprocessable_entity
    assert_equal({ "error" => I18n.t("catalogs.errors.invalid_category") }, response.parsed_body)
  end

  test "create with invalid category returns unprocessable_entity" do
    login_as_employee(@employee)
    assert_no_difference("Catalog.count") do
      post catalogs_path, params: {
        catalog: {
          name: "テスト弁当",
          category: "invalid_category",
          regular_price: 450
        }
      }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_equal({ "error" => I18n.t("catalogs.errors.invalid_category") }, response.parsed_body)
  end
end
