require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  fixtures :employees

  test "validations" do
    @subject = Employee.new(username: "test_employee", password: "password", status: :verified)

    must validate_presence_of(:username)
    must validate_presence_of(:password).on(:create)
    must allow_value("Valid_User123").for(:username)
    wont allow_value("invalid@user").for(:username)
    must define_enum_for(:status).with_values(unverified: 1, verified: 2, closed: 3).validating
  end

  test "associations" do
    @subject = Employee.new

    must have_many(:sales).dependent(:nullify)
    must have_many(:voided_sales).class_name("Sale").dependent(:nullify)
    must have_many(:refunds).dependent(:nullify)
    must have_many(:additional_orders).dependent(:nullify)
  end

  test "ユーザー名は有効なアカウント間で一意であり閉鎖アカウントは再利用できる" do
    duplicate = Employee.new(username: "employee", password: "password", status: :verified)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "はすでに存在します"

    case_variant = Employee.new(username: "EMPLOYEE", password: "password", status: :verified)
    assert_not case_variant.valid?

    reused = Employee.new(username: "closed_employee", password: "password", status: :verified)
    assert reused.valid?

    Employee.create!(username: "duplicate_closed", password: "password", status: :closed)
    second_closed = Employee.new(username: "duplicate_closed", password: "password", status: :closed)
    assert second_closed.valid?
  end
end
