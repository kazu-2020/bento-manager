# frozen_string_literal: true

require "test_helper"

class EmployeesControllerTest < ActionDispatch::IntegrationTest
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
          email: "new-employee@example.com",
          name: "新規従業員",
          password: "password",
          password_confirmation: "password"
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
      employee: { name: "更新された名前" }
    }
    assert_redirected_to admin_employees_path
    @employee.reload
    assert_equal "更新された名前", @employee.name
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
  # Employee認証時のテスト（403 Forbidden）
  # ============================================================

  test "employee cannot access index and gets 403" do
    login_as_employee(@employee)
    get admin_employees_path
    assert_response :forbidden
  end

  test "employee cannot access show and gets 403" do
    login_as_employee(@employee)
    get admin_employee_path(@employee)
    assert_response :forbidden
  end

  test "employee cannot access new and gets 403" do
    login_as_employee(@employee)
    get new_admin_employee_path
    assert_response :forbidden
  end

  test "employee cannot create and gets 403" do
    login_as_employee(@employee)
    assert_no_difference("Employee.count") do
      post admin_employees_path, params: {
        employee: {
          email: "another@example.com",
          name: "別の従業員",
          password: "password",
          password_confirmation: "password"
        }
      }
    end
    assert_response :forbidden
  end

  test "employee cannot access edit and gets 403" do
    login_as_employee(@employee)
    get edit_admin_employee_path(@employee)
    assert_response :forbidden
  end

  test "employee cannot update and gets 403" do
    login_as_employee(@employee)
    original_name = @employee.name
    patch admin_employee_path(@employee), params: {
      employee: { name: "ハッキング試み" }
    }
    assert_response :forbidden
    @employee.reload
    assert_equal original_name, @employee.name
  end

  test "employee cannot destroy and gets 403" do
    login_as_employee(@employee)
    employee_to_delete = employees(:owner_employee)
    assert_no_difference("Employee.count") do
      delete admin_employee_path(employee_to_delete)
    end
    assert_response :forbidden
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
          email: "hacker@example.com",
          name: "ハッカー",
          password: "password",
          password_confirmation: "password"
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
      employee: { name: "ハッキング試み" }
    }
    assert_redirected_to "/admin/login"
  end

  test "unauthenticated user is redirected to login on destroy" do
    assert_no_difference("Employee.count") do
      delete admin_employee_path(@employee)
    end
    assert_redirected_to "/admin/login"
  end
end
