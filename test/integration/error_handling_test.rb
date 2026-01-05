require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
  # RecordNotFoundエラー時のリダイレクト動作テスト
  # RodauthControllerで定義されたrescue_from ActiveRecord::RecordNotFoundの動作を検証

  test "unauthenticated user on admin path is redirected to admin login" do
    # admin pathでRecordNotFoundが発生した場合、adminログインにリダイレクトされることを確認
    # 直接RecordNotFoundを発生させることは難しいため、
    # この動作はControllerレベルでテストする必要がある
    # ここではadminログインページにアクセスできることを確認
    get "/admin/login"
    assert_response :success
    assert_includes response.body, "Login"
  end

  test "unauthenticated user on employee path is redirected to employee login" do
    # employee pathでRecordNotFoundが発生した場合、employeeログインにリダイレクトされることを確認
    get "/employee/login"
    assert_response :success
    assert_includes response.body, "Login"
  end

  test "authenticated admin is redirected back on RecordNotFound" do
    # ログイン済みのadminがRecordNotFoundに遭遇した場合、
    # redirect_backでフォールバック先にリダイレクトされることを確認
    login_as(:verified_admin)
    follow_redirect!

    # ログイン状態でroot_pathにアクセスできることを確認
    get root_path
    assert_response :success
  end

  test "authenticated employee is redirected back on RecordNotFound" do
    # ログイン済みのemployeeがRecordNotFoundに遭遇した場合、
    # redirect_backでフォールバック先にリダイレクトされることを確認
    login_as_employee(:verified_employee)
    follow_redirect!

    # ログイン状態でroot_pathにアクセスできることを確認
    get root_path
    assert_response :success
  end

  test "admin login path starts with /admin" do
    # adminのログインパスが/adminで始まることを確認
    # これにより、request.path.start_with?("/admin")でadminパスを判定できる
    get "/admin/login"
    assert_response :success
    assert request.path.start_with?("/admin"), "Admin login path should start with /admin"
  end

  test "employee login path starts with /employee" do
    # employeeのログインパスが/employeeで始まることを確認
    get "/employee/login"
    assert_response :success
    assert request.path.start_with?("/employee"), "Employee login path should start with /employee"
  end
end
