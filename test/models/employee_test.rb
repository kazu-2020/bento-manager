require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  fixtures :employees

  test "should create employee with email and name and password" do
    employee = Employee.new(email: "new-employee@example.com", name: "テスト従業員", password: "password")
    assert employee.valid?, "Employee should be valid with email, name, and password"
  end

  test "should require email" do
    employee = Employee.new(name: "テスト従業員")
    assert_not employee.valid?, "Employee should not be valid without email"
    assert_includes employee.errors[:email], "を入力してください"
  end

  test "should require unique email" do
    # フィクスチャの verified_employee と同じメールアドレスで作成を試みる
    employee = Employee.new(email: "employee@example.com", name: "重複従業員")
    assert_not employee.valid?, "Employee should not be valid with duplicate email"
    assert_includes employee.errors[:email], "はすでに存在します"
  end

  test "should require name" do
    employee = Employee.new(email: "new-employee@example.com")
    assert_not employee.valid?, "Employee should not be valid without name"
    assert_includes employee.errors[:name], "を入力してください"
  end

  # ステータス遷移テスト
  test "can create employee with verified or closed status" do
    verified_employee = Employee.new(email: "new-verified@example.com", name: "検証済み従業員", password: "password", status: :verified)
    assert verified_employee.valid?, "Employee should be valid with verified status"

    closed_employee = Employee.new(email: "new-closed@example.com", name: "閉鎖済み従業員", password: "password", status: :closed)
    assert closed_employee.valid?, "Employee should be valid with closed status"
  end

  test "can update employee status from verified to closed" do
    employee = employees(:verified_employee)
    assert employee.verified?, "Employee should start as verified"

    employee.update!(status: :closed)
    assert employee.closed?, "Employee status should be updated to closed"
  end

  test "status enum has correct values" do
    assert_equal 1, Employee.statuses[:unverified], "unverified status should be 1"
    assert_equal 2, Employee.statuses[:verified], "verified status should be 2"
    assert_equal 3, Employee.statuses[:closed], "closed status should be 3"
  end

  # メールアドレスユニーク制約テスト
  test "email uniqueness is enforced for verified accounts" do
    # フィクスチャのverified_employeeと同じメールアドレスで作成を試みる
    duplicate_employee = Employee.new(
      email: "employee@example.com",
      name: "重複従業員",
      status: :verified
    )
    assert_not duplicate_employee.valid?, "Should not allow duplicate email for verified accounts"
    assert_includes duplicate_employee.errors[:email], "はすでに存在します"
  end

  test "closed accounts allow email address reuse" do
    # closed_employeeのメールアドレスを使って新しいverifiedアカウントを作成
    reused_email_employee = Employee.new(
      email: "closed-employee@example.com",
      name: "再利用従業員",
      password: "password",
      status: :verified
    )
    # closedアカウントのメールアドレスは再利用可能（部分ユニークインデックスのため）
    assert reused_email_employee.valid?, "Should allow email reuse from closed accounts"
  end

  test "database partial unique index allows duplicate closed emails" do
    # 同じメールアドレスで複数のclosedアカウントを作成
    Employee.create!(
      email: "duplicate-closed@example.com",
      name: "最初の閉鎖従業員",
      password: "password",
      status: :closed
    )

    second_closed = Employee.new(
      email: "duplicate-closed@example.com",
      name: "2番目の閉鎖従業員",
      password: "password",
      status: :closed
    )
    # closedステータス同士は重複可能
    assert second_closed.valid?, "Should allow duplicate emails for closed accounts"
    assert second_closed.save, "Should successfully save duplicate closed account"
  end

  test "unique constraint is case insensitive" do
    # 大文字小文字が異なるメールアドレスで作成を試みる
    case_variant_employee = Employee.new(
      email: "EMPLOYEE@EXAMPLE.COM",
      name: "大文字従業員",
      status: :verified
    )
    # Railsのuniqueness validationでcase_sensitive: falseを指定
    assert_not case_variant_employee.valid?, "Email uniqueness should be case insensitive"
  end
end
