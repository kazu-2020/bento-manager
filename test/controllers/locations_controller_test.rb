# frozen_string_literal: true

require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :admins, :employees, :locations

  setup do
    @admin = admins(:verified_admin)
    @employee = employees(:verified_employee)
    @location = locations(:city_hall)
    @inactive_location = locations(:prefectural_office)
  end

  # ============================================================
  # Admin認証時のテスト（アクセス可能）
  # ============================================================

  test "admin can access index" do
    login_as(@admin)
    get locations_path
    assert_response :success
  end

  test "admin can access show" do
    login_as(@admin)
    get location_path(@location)
    assert_response :success
  end

  test "admin can access new" do
    login_as(@admin)
    get new_location_path, as: :turbo_stream
    assert_response :success
  end

  test "admin can create location" do
    login_as(@admin)
    assert_difference("Location.count") do
      post locations_path, params: {
        location: {
          name: "新規販売先"
        }
      }, as: :turbo_stream
    end
    assert_response :success
  end

  test "admin can access edit" do
    login_as(@admin)
    get edit_location_path(@location)
    assert_response :success
  end

  test "admin can update location" do
    login_as(@admin)
    patch location_path(@location), params: {
      location: { name: "更新された販売先名" }
    }
    assert_response :success
    @location.reload
    assert_equal "更新された販売先名", @location.name
  end

  # ============================================================
  # Employee認証時のテスト（アクセス可能）
  # ============================================================

  test "employee can access index" do
    login_as_employee(@employee)
    get locations_path
    assert_response :success
  end

  test "employee can access show" do
    login_as_employee(@employee)
    get location_path(@location)
    assert_response :success
  end

  test "employee can access new" do
    login_as_employee(@employee)
    get new_location_path, as: :turbo_stream
    assert_response :success
  end

  test "employee can create location" do
    login_as_employee(@employee)
    assert_difference("Location.count") do
      post locations_path, params: {
        location: {
          name: "従業員作成販売先"
        }
      }, as: :turbo_stream
    end
    assert_response :success
  end

  test "employee can access edit" do
    login_as_employee(@employee)
    get edit_location_path(@location)
    assert_response :success
  end

  test "employee can update location" do
    login_as_employee(@employee)
    patch location_path(@location), params: {
      location: { name: "従業員更新販売先名" }
    }
    assert_response :success
    @location.reload
    assert_equal "従業員更新販売先名", @location.name
  end

  # ============================================================
  # 未認証時のテスト（ログインページにリダイレクト）
  # ============================================================

  test "unauthenticated user is redirected to login on index" do
    get locations_path
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on show" do
    get location_path(@location)
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on new" do
    get new_location_path
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on create" do
    assert_no_difference("Location.count") do
      post locations_path, params: {
        location: {
          name: "不正な販売先"
        }
      }
    end
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on edit" do
    get edit_location_path(@location)
    assert_redirected_to "/employee/login"
  end

  test "unauthenticated user is redirected to login on update" do
    patch location_path(@location), params: {
      location: { name: "不正な更新" }
    }
    assert_redirected_to "/employee/login"
  end

  # ============================================================
  # バリデーションエラー時のレスポンステスト
  # ※バリデーションロジック自体のテストはモデルテストで担保
  # ============================================================

  test "create with invalid params renders new with unprocessable_entity" do
    login_as(@admin)
    assert_no_difference("Location.count") do
      post locations_path, params: { location: { name: "" } }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
  end

  test "update with invalid params renders edit with unprocessable_entity" do
    login_as(@admin)
    original_name = @location.name
    patch location_path(@location), params: { location: { name: "" } }
    assert_response :unprocessable_entity
    @location.reload
    assert_equal original_name, @location.name
  end
end
