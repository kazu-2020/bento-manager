require "test_helper"

class AdminTest < ActiveSupport::TestCase
  fixtures :admins

  test "should create admin with email and password" do
    admin = Admin.new(email: "new-admin@example.com", name: "テスト管理者")
    assert admin.valid?, "Admin should be valid with email and name"
  end

  test "should require email" do
    admin = Admin.new(name: "テスト管理者")
    assert_not admin.valid?, "Admin should not be valid without email"
    assert_includes admin.errors[:email], "を入力してください"
  end

  test "should require unique email" do
    # フィクスチャの verified_admin と同じメールアドレスで作成を試みる
    admin = Admin.new(email: "admin@example.com", name: "重複管理者")
    assert_not admin.valid?, "Admin should not be valid with duplicate email"
    assert_includes admin.errors[:email], "はすでに存在します"
  end

  test "should require name" do
    admin = Admin.new(email: "new-admin@example.com")
    assert_not admin.valid?, "Admin should not be valid without name"
    assert_includes admin.errors[:name], "を入力してください"
  end

  # ステータス遷移テスト
  test "can create admin with verified or closed status" do
    verified_admin = Admin.new(email: "new-verified@example.com", name: "検証済み管理者", status: :verified)
    assert verified_admin.valid?, "Admin should be valid with verified status"

    closed_admin = Admin.new(email: "new-closed@example.com", name: "閉鎖済み管理者", status: :closed)
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

  # メールアドレスユニーク制約テスト
  test "email uniqueness is enforced for verified accounts" do
    # フィクスチャのverified_adminと同じメールアドレスで作成を試みる
    duplicate_admin = Admin.new(
      email: "admin@example.com",
      name: "重複管理者",
      status: :verified
    )
    assert_not duplicate_admin.valid?, "Should not allow duplicate email for verified accounts"
    assert_includes duplicate_admin.errors[:email], "はすでに存在します"
  end

  test "closed accounts allow email address reuse" do
    # closed_adminのメールアドレスを使って新しいverifiedアカウントを作成
    reused_email_admin = Admin.new(
      email: "closed@example.com",
      name: "再利用管理者",
      status: :verified
    )
    # closedアカウントのメールアドレスは再利用可能（部分ユニークインデックスのため）
    assert reused_email_admin.valid?, "Should allow email reuse from closed accounts"
  end

  test "database partial unique index allows duplicate closed emails" do
    # 同じメールアドレスで複数のclosedアカウントを作成
    Admin.create!(
      email: "duplicate-closed@example.com",
      name: "最初の閉鎖管理者",
      status: :closed
    )

    second_closed = Admin.new(
      email: "duplicate-closed@example.com",
      name: "2番目の閉鎖管理者",
      status: :closed
    )
    # closedステータス同士は重複可能
    assert second_closed.valid?, "Should allow duplicate emails for closed accounts"
    assert second_closed.save, "Should successfully save duplicate closed account"
  end

  test "unique constraint is case insensitive" do
    # 大文字小文字が異なるメールアドレスで作成を試みる
    case_variant_admin = Admin.new(
      email: "ADMIN@EXAMPLE.COM",
      name: "大文字管理者",
      status: :verified
    )
    # Railsのuniqueness validationはデフォルトでcase_sensitive: trueだが、
    # データベースレベルでの制約チェック
    assert_not case_variant_admin.valid?, "Email uniqueness should be case insensitive"
  end
end
