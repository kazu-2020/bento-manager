# frozen_string_literal: true

require "test_helper"

class Admin::EmployeesControllerTest < ActionDispatch::IntegrationTest
  fixtures :admins, :employees

  setup do
    @admin = admins(:verified_admin)
    @employee = employees(:verified_employee)
  end

  # ============================================================
  # Admin認証時のテスト（アクセス可能）
  # ============================================================

  test "admin can access index" do
    login_as(@admin)
    get admin_employees_path
    assert_response :success
  end

  test "admin can access show" do
    login_as(@admin)
    get admin_employee_path(@employee)
    assert_response :success
  end

  test "admin can access new" do
    login_as(@admin)
    get new_admin_employee_path
    assert_response :success
  end

  test "admin can create employee" do
    login_as(@admin)
    assert_difference("Employee.count") do
      post admin_employees_path, params: {
        employee: {
          username: "new_employee",
          password: "password"
        }
      }
    end
    assert_redirected_to admin_employees_path
  end

  test "admin can access edit" do
    login_as(@admin)
    get edit_admin_employee_path(@employee)
    assert_response :success
  end

  test "admin can update employee" do
    login_as(@admin)
    patch admin_employee_path(@employee), params: {
      employee: { username: "updated_username" }
    }
    assert_redirected_to admin_employees_path
    @employee.reload
    assert_equal "updated_username", @employee.username
  end

  test "admin can destroy employee" do
    login_as(@admin)
    employee_to_delete = employees(:owner_employee)
    assert_difference("Employee.count", -1) do
      delete admin_employee_path(employee_to_delete)
    end
    assert_redirected_to admin_employees_path
  end

  # ============================================================
  # 未認証時のテスト（ログインページにリダイレクト）
  # ============================================================

  test "unauthenticated user is redirected to login on index" do
    get admin_employees_path
    assert_redirected_to "/admin/login"
  end

  test "unauthenticated user is redirected to login on show" do
    get admin_employee_path(@employee)
    assert_redirected_to "/admin/login"
  end

  test "unauthenticated user is redirected to login on new" do
    get new_admin_employee_path
    assert_redirected_to "/admin/login"
  end

  test "unauthenticated user is redirected to login on create" do
    assert_no_difference("Employee.count") do
      post admin_employees_path, params: {
        employee: {
          username: "hacker",
          password: "password"
        }
      }
    end
    assert_redirected_to "/admin/login"
  end

  test "unauthenticated user is redirected to login on edit" do
    get edit_admin_employee_path(@employee)
    assert_redirected_to "/admin/login"
  end

  test "unauthenticated user is redirected to login on update" do
    patch admin_employee_path(@employee), params: {
      employee: { username: "hacking_attempt" }
    }
    assert_redirected_to "/admin/login"
  end

  test "unauthenticated user is redirected to login on destroy" do
    assert_no_difference("Employee.count") do
      delete admin_employee_path(@employee)
    end
    assert_redirected_to "/admin/login"
  end

  # ============================================================
  # Employee認証時のテスト（ログインページにリダイレクト）
  # Employee認証はAdmin認証として認識されないため、ログインページにリダイレクト
  # ============================================================

  test "employee accessing index is redirected to admin login" do
    login_as_employee(@employee)
    get admin_employees_path
    assert_redirected_to "/admin/login"
  end

  test "employee accessing show is redirected to admin login" do
    login_as_employee(@employee)
    get admin_employee_path(@employee)
    assert_redirected_to "/admin/login"
  end

  test "employee accessing new is redirected to admin login" do
    login_as_employee(@employee)
    get new_admin_employee_path
    assert_redirected_to "/admin/login"
  end

  test "employee creating is redirected to admin login" do
    login_as_employee(@employee)
    assert_no_difference("Employee.count") do
      post admin_employees_path, params: {
        employee: {
          username: "another_employee",
          password: "password"
        }
      }
    end
    assert_redirected_to "/admin/login"
  end

  test "employee accessing edit is redirected to admin login" do
    login_as_employee(@employee)
    get edit_admin_employee_path(@employee)
    assert_redirected_to "/admin/login"
  end

  test "employee updating is redirected to admin login" do
    login_as_employee(@employee)
    original_username = @employee.username
    patch admin_employee_path(@employee), params: {
      employee: { username: "hacking_attempt" }
    }
    assert_redirected_to "/admin/login"
    @employee.reload
    assert_equal original_username, @employee.username
  end

  test "employee deleting is redirected to admin login" do
    login_as_employee(@employee)
    employee_to_delete = employees(:owner_employee)
    assert_no_difference("Employee.count") do
      delete admin_employee_path(employee_to_delete)
    end
    assert_redirected_to "/admin/login"
  end
end
