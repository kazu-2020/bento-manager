require "test_helper"

class AdminTest < ActiveSupport::TestCase
  fixtures :admins

  test "should create admin with username" do
    admin = Admin.new(username: "new_admin")
    assert admin.valid?, "Admin should be valid with username"
  end

  test "should require username" do
    admin = Admin.new
    assert_not admin.valid?, "Admin should not be valid without username"
    assert_includes admin.errors[:username], "を入力してください"
  end

  test "should require unique username" do
    # フィクスチャの verified_admin と同じアカウント名で作成を試みる
    admin = Admin.new(username: "admin")
    assert_not admin.valid?, "Admin should not be valid with duplicate username"
    assert_includes admin.errors[:username], "はすでに存在します"
  end

  test "should require valid username format" do
    # 無効な文字を含むusername
    admin = Admin.new(username: "invalid@user")
    assert_not admin.valid?, "Admin should not be valid with invalid username format"
    assert_includes admin.errors[:username], "は不正な値です"
  end

  test "should accept valid username format" do
    admin = Admin.new(username: "Valid_User123")
    assert admin.valid?, "Admin should be valid with alphanumeric and underscore username"
  end

  # ステータス遷移テスト
  test "can create admin with verified or closed status" do
    verified_admin = Admin.new(username: "new_verified", status: :verified)
    assert verified_admin.valid?, "Admin should be valid with verified status"

    closed_admin = Admin.new(username: "new_closed", status: :closed)
    assert closed_admin.valid?, "Admin should be valid with closed status"
  end

  test "can update admin status from verified to closed" do
    admin = admins(:verified_admin)
    assert admin.verified?, "Admin should start as verified"

    admin.update!(status: :closed)
    assert admin.closed?, "Admin status should be updated to closed"
  end

  test "status enum has correct values" do
    assert_equal 1, Admin.statuses[:unverified], "unverified status should be 1"
    assert_equal 2, Admin.statuses[:verified], "verified status should be 2"
    assert_equal 3, Admin.statuses[:closed], "closed status should be 3"
  end

  # アカウント名ユニーク制約テスト
  test "username uniqueness is enforced for verified accounts" do
    # フィクスチャのverified_adminと同じアカウント名で作成を試みる
    duplicate_admin = Admin.new(
      username: "admin",
      status: :verified
    )
    assert_not duplicate_admin.valid?, "Should not allow duplicate username for verified accounts"
    assert_includes duplicate_admin.errors[:username], "はすでに存在します"
  end

  test "closed accounts allow username reuse" do
    # closed_adminのアカウント名を使って新しいverifiedアカウントを作成
    reused_username_admin = Admin.new(
      username: "closed_admin",
      status: :verified
    )
    # closedアカウントのアカウント名は再利用可能（部分ユニークインデックスのため）
    assert reused_username_admin.valid?, "Should allow username reuse from closed accounts"
  end

  test "database partial unique index allows duplicate closed usernames" do
    # 同じアカウント名で複数のclosedアカウントを作成
    Admin.create!(
      username: "duplicate_closed",
      status: :closed
    )

    second_closed = Admin.new(
      username: "duplicate_closed",
      status: :closed
    )
    # closedステータス同士は重複可能
    assert second_closed.valid?, "Should allow duplicate usernames for closed accounts"
    assert second_closed.save, "Should successfully save duplicate closed account"
  end

  test "unique constraint is case insensitive" do
    # 大文字小文字が異なるアカウント名で作成を試みる
    case_variant_admin = Admin.new(
      username: "ADMIN",
      status: :verified
    )
    # Railsのuniqueness validationでcase_sensitive: falseを指定
    assert_not case_variant_admin.valid?, "Username uniqueness should be case insensitive"
  end
end
