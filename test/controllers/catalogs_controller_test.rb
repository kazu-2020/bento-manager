# frozen_string_literal: true

require "test_helper"

class CatalogsControllerTest < ActionDispatch::IntegrationTest
  fixtures :admins, :employees, :catalogs

  setup do
    @admin = admins(:verified_admin)
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
    login_as(@admin)
    get catalogs_path
    assert_response :success
  end

  test "admin can access show" do
    login_as(@admin)
    get catalog_path(@catalog)
    assert_response :success
  end

  test "admin can access new" do
    login_as(@admin)
    get new_catalog_path
    assert_response :success
  end

  test "admin can create catalog" do
    login_as(@admin)
    assert_difference("Catalog.count") do
      post catalogs_path, params: {
        catalog: {
          name: "新規弁当",
          category: "bento",
          description: "新商品の説明"
        }
      }
    end
    assert_redirected_to catalogs_path
  end

  test "admin can access edit" do
    login_as(@admin)
    get edit_catalog_path(@catalog)
    assert_response :success
  end

  test "admin can update catalog" do
    login_as(@admin)
    patch catalog_path(@catalog), params: {
      catalog: { name: "更新された弁当名" }
    }
    assert_redirected_to catalogs_path
    @catalog.reload
    assert_equal "更新された弁当名", @catalog.name
  end

  test "admin can destroy catalog (creates CatalogDiscontinuation)" do
    login_as(@admin)
    assert_no_difference("Catalog.count") do
      assert_difference("CatalogDiscontinuation.count") do
        delete catalog_path(@catalog)
      end
    end
    assert_redirected_to catalogs_path
    @catalog.reload
    assert @catalog.discontinued?
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
    get new_catalog_path
    assert_response :success
  end

  test "employee can create catalog" do
    login_as_employee(@employee)
    assert_difference("Catalog.count") do
      post catalogs_path, params: {
        catalog: {
          name: "従業員作成弁当",
          category: "bento",
          description: "従業員が作成"
        }
      }
    end
    assert_redirected_to catalogs_path
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
    }
    assert_redirected_to catalogs_path
    @catalog.reload
    assert_equal "従業員更新弁当名", @catalog.name
  end

  test "employee can destroy catalog (creates CatalogDiscontinuation)" do
    login_as_employee(@employee)
    assert_no_difference("Catalog.count") do
      assert_difference("CatalogDiscontinuation.count") do
        delete catalog_path(@catalog)
      end
    end
    assert_redirected_to catalogs_path
    @catalog.reload
    assert @catalog.discontinued?
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

  test "unauthenticated user is redirected to login on destroy" do
    assert_no_difference("CatalogDiscontinuation.count") do
      delete catalog_path(@catalog)
    end
    assert_redirected_to "/employee/login"
    @catalog.reload
    assert_not @catalog.discontinued?
  end

  # ============================================================
  # バリデーションエラー時のレスポンステスト
  # ※バリデーションロジック自体のテストはモデルテストで担保
  # ============================================================

  test "create with blank name renders new with unprocessable_entity" do
    login_as(@admin)
    assert_no_difference("Catalog.count") do
      post catalogs_path, params: { catalog: { name: "", category: "bento" } }
    end
    assert_response :unprocessable_entity
  end

  test "create with blank category renders new with unprocessable_entity" do
    login_as(@admin)
    assert_no_difference("Catalog.count") do
      post catalogs_path, params: { catalog: { name: "テスト弁当", category: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "update with invalid params renders edit with unprocessable_entity" do
    login_as(@admin)
    original_name = @catalog.name
    patch catalog_path(@catalog), params: { catalog: { name: "" } }
    assert_response :unprocessable_entity
    @catalog.reload
    assert_equal original_name, @catalog.name
  end

  # ============================================================
  # destroy 特有のテスト
  # ============================================================

  test "destroy already discontinued catalog redirects with alert" do
    login_as(@admin)
    assert_no_difference("CatalogDiscontinuation.count") do
      delete catalog_path(@discontinued_catalog)
    end
    assert_redirected_to catalogs_path
    assert_equal I18n.t("catalogs.destroy.already_discontinued"), flash[:alert]
  end

  test "destroy creates CatalogDiscontinuation with reason" do
    login_as(@admin)
    delete catalog_path(@catalog), params: { reason: "季節終了のため" }
    assert_redirected_to catalogs_path
    @catalog.reload
    assert @catalog.discontinued?
    assert_equal "季節終了のため", @catalog.discontinuation.reason
  end

  test "destroy creates CatalogDiscontinuation with default reason when not provided" do
    login_as(@admin)
    delete catalog_path(@catalog)
    assert_redirected_to catalogs_path
    @catalog.reload
    assert @catalog.discontinued?
    assert_equal I18n.t("catalogs.destroy.default_reason"), @catalog.discontinuation.reason
  end
end
