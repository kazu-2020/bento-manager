require "test_helper"

class AdminAuthenticationTest < ActionDispatch::IntegrationTest
  test "admin can login successfully" do
    # Navigate to login page
    get "/login"
    assert_response :success

    # Submit login with valid credentials
    post "/login", params: {
      email: "freddie@queen.com",
      password: "password"
    }

    # Assert redirect after successful login
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "admin cannot login with invalid credentials" do
    get "/login"
    assert_response :success

    # Submit login with invalid credentials
    post "/login", params: {
      email: "invalid@example.com",
      password: "wrong_password"
    }

    # Rodauth returns 401 Unauthorized for invalid credentials
    assert_response :unauthorized
  end

  test "admin can logout" do
    # Login first
    post "/login", params: {
      email: "freddie@queen.com",
      password: "password"
    }
    assert_response :redirect

    # Logout (Rodauth uses POST for logout, not DELETE)
    post "/logout"

    # Assert redirect after logout
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end
end
