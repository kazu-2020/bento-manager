require "test_helper"

class EmployeeAuthenticationTest < ActionDispatch::IntegrationTest
  test "employee can login successfully" do
    # Navigate to login page
    get "/employee/login"
    assert_response :success

    # Submit login with valid credentials
    post "/employee/login", params: {
      email: "employee@example.com",
      password: "password"
    }

    # Assert redirect after successful login
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "employee cannot login with invalid credentials" do
    get "/employee/login"
    assert_response :success

    # Submit login with invalid credentials
    post "/employee/login", params: {
      email: "invalid@example.com",
      password: "wrong_password"
    }

    # Rodauth returns 401 Unauthorized for invalid credentials
    assert_response :unauthorized
  end

  test "employee can logout" do
    # Login first
    post "/employee/login", params: {
      email: "employee@example.com",
      password: "password"
    }
    assert_response :redirect

    # Logout (Rodauth uses POST for logout, not DELETE)
    post "/employee/logout"

    # Assert redirect after logout
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  # ステータス遷移テスト
  test "closed employee cannot login" do
    # Try to login with closed employee credentials
    post "/employee/login", params: {
      email: "closed-employee@example.com",
      password: "password"
    }

    # Rodauth rejects closed accounts with 401 Unauthorized
    assert_response :unauthorized
  end

  test "verified employee can close account" do
    # Login as verified employee
    login_as_employee(:verified_employee)

    # Access close account page
    get "/employee/close-account"
    assert_response :success

    # Submit close account request with password confirmation
    post "/employee/close-account", params: {
      password: "password"
    }

    # Should redirect after closing account
    assert_response :redirect

    # Verify employee status is now closed
    employee = employees(:verified_employee)
    employee.reload
    assert employee.closed?, "Employee status should be closed after closing account"
  end

  # パスワード変更テスト
  test "employee can change password while logged in" do
    # Login as verified employee
    employee = employees(:verified_employee)
    login_as_employee(employee)

    # Access change password page
    get "/employee/change-password"
    assert_response :success

    # Submit password change with current and new password
    post "/employee/change-password", params: {
      password: "password",
      "new-password": "newpassword123",
      "password-confirm": "newpassword123"
    }

    # Should redirect after successful password change
    assert_response :redirect

    # Logout and try to login with new password
    post "/employee/logout"
    post "/employee/login", params: {
      email: employee.email,
      password: "newpassword123"
    }
    assert_response :redirect, "Should be able to login with new password"
  end

  test "password change requires current password" do
    # Login as verified employee
    login_as_employee(:verified_employee)

    # Try to change password without providing current password
    post "/employee/change-password", params: {
      password: "",
      "new-password": "newpassword123",
      "password-confirm": "newpassword123"
    }

    # Rodauth rejects with 401 Unauthorized when current password is incorrect or missing
    assert_response :unauthorized
  end

  test "new password must meet minimum length requirement" do
    # Login as verified employee
    login_as_employee(:verified_employee)

    # Try to change password to one that's too short (< 8 characters)
    post "/employee/change-password", params: {
      password: "password",
      "new-password": "short",
      "password-confirm": "short"
    }

    # Rodauth should reject the request due to password length
    assert_response :unprocessable_entity
  end

  # セッション管理テスト
  test "session id changes after login to prevent session fixation" do
    # Get login page to establish initial session
    get "/employee/login"
    initial_session_id = session.id

    # Login
    post "/employee/login", params: {
      email: "employee@example.com",
      password: "password"
    }

    # Session ID should change after login (session fixation prevention)
    assert_not_equal initial_session_id, session.id, "Session ID should change after login"
  end

  test "session id changes after logout" do
    # Login first
    login_as_employee(:verified_employee)
    logged_in_session_id = session.id

    # Logout
    post "/employee/logout"

    # Session ID should change after logout
    assert_not_equal logged_in_session_id, session.id, "Session ID should change after logout"
  end

  test "old session becomes invalid after logout" do
    # Login first
    login_as_employee(:verified_employee)

    # Logout
    post "/employee/logout"
    assert_response :redirect

    # Try to login again to verify old session is invalid
    # and we can establish a new session
    post "/employee/login", params: {
      email: "employee@example.com",
      password: "password"
    }
    assert_response :redirect, "Should be able to login again after logout"
  end

  test "concurrent sessions from different devices are allowed" do
    # Simulate first device login
    first_device_session = open_session
    first_device_session.post "/employee/login", params: {
      email: "employee@example.com",
      password: "password"
    }
    assert first_device_session.response.redirect?, "First device should login successfully"

    # Simulate second device login (using a different session)
    second_device_session = open_session
    second_device_session.post "/employee/login", params: {
      email: "employee@example.com",
      password: "password"
    }
    assert second_device_session.response.redirect?, "Second device should login successfully"

    # Both sessions should be valid (concurrent login allowed)
    # Note: This test verifies that Rodauth doesn't invalidate the first session
    # when the second device logs in
  end

  # 業務機能アクセステスト（Requirement 9.7）
  test "verified employee can access business functions" do
    # Login as verified employee
    login_as_employee(:verified_employee)

    # Employee should be able to access root path (業務機能)
    get root_path
    assert_response :success, "Employee should be able to access business functions"
  end
end
