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

  # 3.1 default_scope テスト
  test "default_scope は active のみ取得" do
    active = Location.create!(name: "テスト市役所C")
    inactive = Location.create!(name: "テスト県庁D", status: :inactive)

    assert_includes Location.all, active
    assert_not_includes Location.all, inactive
  end

  test "unscoped で inactive も取得可能" do
    inactive = Location.create!(name: "テスト県庁E", status: :inactive)
    assert_includes Location.unscoped, inactive
  end

  # 3.1 activate/deactivate メソッドテスト
  test "deactivate で status を inactive に変更" do
    location = Location.create!(name: "テスト市役所F")
    assert location.active?

    location.deactivate
    assert location.inactive?
  end

  test "activate で status を active に変更" do
    location = Location.unscoped.create!(name: "テスト県庁G", status: :inactive)
    assert location.inactive?

    location.activate
    assert location.active?
  end
end
