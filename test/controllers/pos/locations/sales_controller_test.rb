# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    class SalesControllerTest < ActionDispatch::IntegrationTest
      fixtures :admins, :employees, :locations, :catalogs, :daily_inventories

      setup do
        @admin = admins(:verified_admin)
        @employee = employees(:verified_employee)
        @location = locations(:city_hall)
      end

      # ============================================================
      # new アクションのテスト
      # ============================================================

      test "admin can access new page" do
        login_as(@admin)
        get new_pos_location_sale_path(@location)
        assert_response :success
      end

      test "employee can access new page" do
        login_as_employee(@employee)
        get new_pos_location_sale_path(@location)
        assert_response :success
      end

      test "new page displays today inventories" do
        login_as(@admin)
        get new_pos_location_sale_path(@location)
        assert_response :success
        # city_hall has today inventories from fixtures
        assert_select "li", minimum: 1
      end

      test "new page displays location name" do
        login_as(@admin)
        get new_pos_location_sale_path(@location)
        assert_response :success
        assert_select "h1", text: @location.name
      end

      test "unauthenticated user is redirected to login on new" do
        get new_pos_location_sale_path(@location)
        assert_redirected_to "/employee/login"
      end

      test "new returns 404 for inactive location" do
        login_as(@admin)
        inactive_location = locations(:prefectural_office)
        get new_pos_location_sale_path(inactive_location)
        assert_response :not_found
      end

      test "new returns 404 for non-existent location" do
        login_as(@admin)
        get new_pos_location_sale_path(location_id: 999999)
        assert_response :not_found
      end
    end
  end
end
