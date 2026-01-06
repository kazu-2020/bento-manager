require "test_helper"

class LocationTest < ActiveSupport::TestCase
  # 3.2 バリデーションテスト
  test "name は必須" do
    location = Location.new(name: nil)
    assert_not location.valid?
    assert_includes location.errors[:name], "を入力してください"
  end

  test "name は一意" do
    Location.create!(name: "テスト市役所A")
    duplicate = Location.new(name: "テスト市役所A")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "はすでに存在します"
  end

  # 3.1 Enum テスト
  test "status enum は active と inactive を持つ" do
    assert_equal 0, Location.statuses[:active]
    assert_equal 1, Location.statuses[:inactive]
  end

  test "デフォルト status は active" do
    location = Location.create!(name: "テスト県庁B")
    assert location.active?
  end

  # 3.1 enum スコープテスト（enum デフォルト機能）
  test "active スコープは active のみ取得" do
    active = Location.create!(name: "テスト市役所C")
    inactive = Location.create!(name: "テスト県庁D", status: :inactive)

    assert_includes Location.active, active
    assert_not_includes Location.active, inactive
  end

  test "all は active と inactive の両方を取得" do
    active = Location.create!(name: "テスト市役所E")
    inactive = Location.create!(name: "テスト県庁F", status: :inactive)

    assert_includes Location.all, active
    assert_includes Location.all, inactive
  end

  # 3.1 enum 更新メソッドテスト（enum デフォルト機能）
  test "inactive! で status を inactive に変更" do
    location = Location.create!(name: "テスト市役所G")
    assert location.active?

    location.inactive!
    assert location.inactive?
  end

  test "active! で status を active に変更" do
    location = Location.create!(name: "テスト県庁H", status: :inactive)
    assert location.inactive?

    location.active!
    assert location.active?
  end
end
