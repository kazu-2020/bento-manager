require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
  # RodauthControllerのrescue_from ActiveRecord::RecordNotFoundの動作を検証
  # テスト専用ルート（/admin/test-record-not-found, /employee/test-record-not-found）を使用

  # === RecordNotFound: 未認証ユーザーのテスト ===

  test "unauthenticated user hitting admin path RecordNotFound is redirected to admin login" do
    get "/admin/test-record-not-found"
    assert_response :redirect
    assert_redirected_to "/admin/login"
    assert_equal I18n.t("custom_errors.controllers.record_not_found"), flash[:error]
  end

  test "unauthenticated user hitting employee path RecordNotFound is redirected to employee login" do
    get "/employee/test-record-not-found"
    assert_response :redirect
    assert_redirected_to "/employee/login"
    assert_equal I18n.t("custom_errors.controllers.record_not_found"), flash[:error]
  end

  # === RecordNotFound: 認証済みユーザーのテスト ===

  test "authenticated admin is redirected back on RecordNotFound" do
    login_as(:verified_admin)

    get "/admin/test-record-not-found"
    assert_response :redirect
    # redirect_back with fallback_location: root_path
    assert_redirected_to root_path
    assert_equal I18n.t("custom_errors.controllers.record_not_found"), flash[:error]
  end

  test "authenticated employee is redirected back on RecordNotFound" do
    login_as_employee(:verified_employee)

    get "/employee/test-record-not-found"
    assert_response :redirect
    assert_redirected_to root_path
    assert_equal I18n.t("custom_errors.controllers.record_not_found"), flash[:error]
  end

  # === パスプレフィックス検証 ===

  test "admin login path starts with /admin" do
    get "/admin/login"
    assert_response :success
    assert request.path.start_with?("/admin"),
      "Admin login path should start with /admin"
  end

  test "employee login path starts with /employee" do
    get "/employee/login"
    assert_response :success
    assert request.path.start_with?("/employee"),
      "Employee login path should start with /employee"
  end
end
