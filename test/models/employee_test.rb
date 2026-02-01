require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  fixtures :employees

  test "should create employee with username and password" do
    employee = Employee.new(username: "new_employee", password: "password")
    assert employee.valid?, "Employee should be valid with username and password"
  end

  test "should require username" do
    employee = Employee.new(password: "password")
    assert_not employee.valid?, "Employee should not be valid without username"
    assert_includes employee.errors[:username], "を入力してください"
  end

  test "should require unique username" do
    # フィクスチャの verified_employee と同じアカウント名で作成を試みる
    employee = Employee.new(username: "employee", password: "password")
    assert_not employee.valid?, "Employee should not be valid with duplicate username"
    assert_includes employee.errors[:username], "はすでに存在します"
  end

  test "should require valid username format" do
    # 無効な文字を含むusername
    employee = Employee.new(username: "invalid@user", password: "password")
    assert_not employee.valid?, "Employee should not be valid with invalid username format"
    assert_includes employee.errors[:username], "は不正な値です"
  end

  test "should accept valid username format" do
    employee = Employee.new(username: "Valid_User123", password: "password")
    assert employee.valid?, "Employee should be valid with alphanumeric and underscore username"
  end

  # ステータス遷移テスト
  test "can create employee with verified or closed status" do
    verified_employee = Employee.new(username: "new_verified", password: "password", status: :verified)
    assert verified_employee.valid?, "Employee should be valid with verified status"

    closed_employee = Employee.new(username: "new_closed", password: "password", status: :closed)
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

  # アカウント名ユニーク制約テスト
  test "username uniqueness is enforced for verified accounts" do
    # フィクスチャのverified_employeeと同じアカウント名で作成を試みる
    duplicate_employee = Employee.new(
      username: "employee",
      password: "password",
      status: :verified
    )
    assert_not duplicate_employee.valid?, "Should not allow duplicate username for verified accounts"
    assert_includes duplicate_employee.errors[:username], "はすでに存在します"
  end

  test "closed accounts allow username reuse" do
    # closed_employeeのアカウント名を使って新しいverifiedアカウントを作成
    reused_username_employee = Employee.new(
      username: "closed_employee",
      password: "password",
      status: :verified
    )
    # closedアカウントのアカウント名は再利用可能（部分ユニークインデックスのため）
    assert reused_username_employee.valid?, "Should allow username reuse from closed accounts"
  end

  test "database partial unique index allows duplicate closed usernames" do
    # 同じアカウント名で複数のclosedアカウントを作成
    Employee.create!(
      username: "duplicate_closed",
      password: "password",
      status: :closed
    )

    second_closed = Employee.new(
      username: "duplicate_closed",
      password: "password",
      status: :closed
    )
    # closedステータス同士は重複可能
    assert second_closed.valid?, "Should allow duplicate usernames for closed accounts"
    assert second_closed.save, "Should successfully save duplicate closed account"
  end

  test "unique constraint is case insensitive" do
    # 大文字小文字が異なるアカウント名で作成を試みる
    case_variant_employee = Employee.new(
      username: "EMPLOYEE",
      password: "password",
      status: :verified
    )
    # Railsのuniqueness validationでcase_sensitive: falseを指定
    assert_not case_variant_employee.valid?, "Username uniqueness should be case insensitive"
    assert_includes case_variant_employee.errors[:username], "はすでに存在します"
  end
end
