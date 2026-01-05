require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "should create admin with email and password" do
    admin = Admin.new(email: "admin@example.com", name: "Test Admin")
    assert admin.valid?, "Admin should be valid with email and name"
  end

  test "should require email" do
    admin = Admin.new(name: "Test Admin")
    assert_not admin.valid?, "Admin should not be valid without email"
    assert_includes admin.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    Admin.create!(email: "admin@example.com", name: "Admin 1", password: "password123")
    admin = Admin.new(email: "admin@example.com", name: "Admin 2", password: "password123")
    assert_not admin.valid?, "Admin should not be valid with duplicate email"
    assert_includes admin.errors[:email], "has already been taken"
  end

  test "should require name" do
    admin = Admin.new(email: "admin@example.com")
    assert_not admin.valid?, "Admin should not be valid without name"
    assert_includes admin.errors[:name], "can't be blank"
  end
end
