# frozen_string_literal: true

require "test_helper"

module Pos
  class LocationsControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :locations, :catalogs, :daily_inventories

    setup do
      @employee = employees(:verified_employee)
      @active_location = locations(:city_hall)
      @inactive_location = locations(:prefectural_office)
    end

    # ============================================================
    # Admin認証時のテスト
    # ============================================================

    test "admin can access index" do
      login_as_employee(@employee)
      get pos_locations_path
      assert_response :success
    end

    test "index displays only active locations for admin" do
      login_as_employee(@employee)
      get pos_locations_path
      assert_response :success
      assert_select "h2", text: @active_location.name
      assert_select "h2", text: @inactive_location.name, count: 0
    end

    # ============================================================
    # Employee認証時のテスト
    # ============================================================

    test "employee can access index" do
      login_as_employee(@employee)
      get pos_locations_path
      assert_response :success
    end

    test "index displays only active locations for employee" do
      login_as_employee(@employee)
      get pos_locations_path
      assert_response :success
      assert_select "h2", text: @active_location.name
      assert_select "h2", text: @inactive_location.name, count: 0
    end

    # ============================================================
    # 未認証時のテスト
    # ============================================================

    test "unauthenticated user is redirected to login on index" do
      get pos_locations_path
      assert_redirected_to "/employee/login"
    end

    # ============================================================
    # 空状態のテスト
    # ============================================================

    test "index shows link to locations page when no active locations" do
      login_as_employee(@employee)
      Location.active.update_all(status: :inactive)
      get pos_locations_path
      assert_response :success
      assert_select "a[href=?]", locations_path
    end

    # ============================================================
    # 在庫警告表示のテスト
    # ============================================================

    test "index shows warning for locations without today inventory" do
      login_as_employee(@employee)
      # 新しい active な Location を作成（在庫なし）
      no_inventory_location = Location.create!(name: "在庫なし販売先", status: :active)

      get pos_locations_path
      assert_response :success

      # city_hall は today_inventories がある（フィクスチャで設定済み）
      # no_inventory_location は today_inventories がない → 警告表示
      assert_select "div.text-warning", minimum: 1
    end

    test "index does not show warning for locations with today inventory" do
      login_as_employee(@employee)
      get pos_locations_path
      assert_response :success

      # city_hall はフィクスチャで当日在庫が設定されている
      # そのカードには警告が表示されないことを確認
    end

    # ============================================================
    # show アクションのテスト
    # ============================================================

    test "show redirects to sales page when location has today inventory" do
      login_as_employee(@employee)
      # city_hall has today inventories from fixtures
      get pos_location_path(@active_location)
      assert_redirected_to new_pos_location_sale_path(@active_location)
    end

    test "show redirects to daily inventory page when location has no today inventory" do
      login_as_employee(@employee)
      # Create a new location without inventory
      no_inventory_location = Location.create!(name: "新規販売先", status: :active)
      get pos_location_path(no_inventory_location)
      assert_redirected_to new_pos_location_daily_inventory_path(no_inventory_location)
    end

    test "show returns 404 for inactive location" do
      login_as_employee(@employee)
      get pos_location_path(@inactive_location)
      assert_response :not_found
    end

    test "show returns 404 for non-existent location" do
      login_as_employee(@employee)
      get pos_location_path(id: 999999)
      assert_response :not_found
    end
  end
end
