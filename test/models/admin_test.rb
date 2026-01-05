require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "should create admin with email and password" do
    admin = Admin.new(email: "new-admin@example.com", name: "テスト管理者")
    assert admin.valid?, "Admin should be valid with email and name"
  end

  test "should require email" do
    admin = Admin.new(name: "テスト管理者")
    assert_not admin.valid?, "Admin should not be valid without email"
    assert_includes admin.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    # フィクスチャの verified_admin と同じメールアドレスで作成を試みる
    admin = Admin.new(email: "admin@example.com", name: "重複管理者")
    assert_not admin.valid?, "Admin should not be valid with duplicate email"
    assert_includes admin.errors[:email], "has already been taken"
  end

  test "should require name" do
    admin = Admin.new(email: "new-admin@example.com")
    assert_not admin.valid?, "Admin should not be valid without name"
    assert_includes admin.errors[:name], "can't be blank"
  end
end
