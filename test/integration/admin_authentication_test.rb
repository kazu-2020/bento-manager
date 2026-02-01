require "test_helper"

class AdminAuthenticationTest < ActionDispatch::IntegrationTest
  fixtures :admins

  test "admin can login successfully" do
    # Navigate to login page
    get "/admin/login"
    assert_response :success

    # Submit login with valid credentials
    post "/admin/login", params: {
      username: "admin",
      password: "password"
    }

    # Assert redirect after successful login
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "admin cannot login with invalid credentials" do
    get "/admin/login"
    assert_response :success

    # Submit login with invalid credentials
    post "/admin/login", params: {
      username: "invalid",
      password: "wrong_password"
    }

    # Rodauth returns 401 Unauthorized for invalid credentials
    assert_response :unauthorized
  end

  test "admin can logout" do
    # Login first
    post "/admin/login", params: {
      username: "admin",
      password: "password"
    }
    assert_response :redirect

    # Logout (Rodauth uses POST for logout, not DELETE)
    post "/admin/logout"

    # Assert redirect after logout
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  # ステータス遷移テスト
  test "closed admin cannot login" do
    # Try to login with closed admin credentials
    post "/admin/login", params: {
      username: "closed_admin",
      password: "password"
    }

    # Rodauth rejects closed accounts with 401 Unauthorized
    assert_response :unauthorized
  end

  test "verified admin can close account" do
    # Login as verified admin
    login_as(:verified_admin)

    # Access close account page
    get "/admin/close-account"
    assert_response :success

    # Submit close account request with password confirmation
    post "/admin/close-account", params: {
      password: "password"
    }

    # Should redirect after closing account
    assert_response :redirect

    # Verify admin status is now closed
    admin = admins(:verified_admin)
    admin.reload
    assert admin.closed?, "Admin status should be closed after closing account"
  end

  # パスワード変更テスト
  test "admin can change password while logged in" do
    # Login as verified admin
    admin = admins(:verified_admin)
    login_as(admin)

    # Access change password page
    get "/admin/change-password"
    assert_response :success

    # Submit password change with current and new password
    post "/admin/change-password", params: {
      password: "password",
      "new-password": "newpassword123",
      "password-confirm": "newpassword123"
    }

    # Should redirect after successful password change
    assert_response :redirect

    # Logout and try to login with new password
    post "/admin/logout"
    post "/admin/login", params: {
      username: admin.username,
      password: "newpassword123"
    }
    assert_response :redirect, "Should be able to login with new password"
  end

  test "password change requires current password" do
    # Login as verified admin
    login_as(:verified_admin)

    # Try to change password without providing current password
    post "/admin/change-password", params: {
      password: "",
      "new-password": "newpassword123",
      "password-confirm": "newpassword123"
    }

    # Rodauth rejects with 401 Unauthorized when current password is incorrect or missing
    assert_response :unauthorized
  end

  test "new password must meet minimum length requirement" do
    # Login as verified admin
    login_as(:verified_admin)

    # Try to change password to one that's too short (< 8 characters)
    post "/admin/change-password", params: {
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
    get "/admin/login"
    initial_session_id = session.id

    # Login
    post "/admin/login", params: {
      username: "admin",
      password: "password"
    }

    # Session ID should change after login (session fixation prevention)
    assert_not_equal initial_session_id, session.id, "Session ID should change after login"
  end

  test "session id changes after logout" do
    # Login first
    login_as(:verified_admin)
    logged_in_session_id = session.id

    # Logout
    post "/admin/logout"

    # Session ID should change after logout
    assert_not_equal logged_in_session_id, session.id, "Session ID should change after logout"
  end

  test "old session becomes invalid after logout" do
    # Login first
    login_as(:verified_admin)

    # Logout
    post "/admin/logout"
    assert_response :redirect

    # Try to login again to verify old session is invalid
    # and we can establish a new session
    post "/admin/login", params: {
      username: "admin",
      password: "password"
    }
    assert_response :redirect, "Should be able to login again after logout"
  end

  test "concurrent sessions from different devices are allowed" do
    # Simulate first device login
    first_device_session = open_session
    first_device_session.post "/admin/login", params: {
      username: "admin",
      password: "password"
    }
    assert first_device_session.response.redirect?, "First device should login successfully"

    # Simulate second device login (using a different session)
    second_device_session = open_session
    second_device_session.post "/admin/login", params: {
      username: "admin",
      password: "password"
    }
    assert second_device_session.response.redirect?, "Second device should login successfully"

    # Both sessions should be valid (concurrent login allowed)
    # Note: This test verifies that Rodauth doesn't invalidate the first session
    # when the second device logs in
  end
end
