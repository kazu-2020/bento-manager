# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    class AdditionalOrdersControllerTest < ActionDispatch::IntegrationTest
      fixtures :employees, :locations, :catalogs, :daily_inventories

      setup do
        @employee = employees(:verified_employee)
        @location = locations(:city_hall)
        @bento_a = catalogs(:daily_bento_a)
        @bento_b = catalogs(:daily_bento_b)
      end

      # ============================================================
      # index アクションのテスト
      # ============================================================

      test "admin can access index page" do
        login_as_employee(@employee)
        get pos_location_additional_orders_path(@location)
        assert_response :success
      end

      test "employee can access index page" do
        login_as_employee(@employee)
        get pos_location_additional_orders_path(@location)
        assert_response :success
      end

      test "unauthenticated user is redirected to login on index" do
        get pos_location_additional_orders_path(@location)
        assert_redirected_to "/employee/login"
      end

      test "index returns 404 for inactive location" do
        login_as_employee(@employee)
        inactive_location = locations(:prefectural_office)
        get pos_location_additional_orders_path(inactive_location)
        assert_response :not_found
      end

      test "index page displays inventory summary" do
        login_as_employee(@employee)
        get pos_location_additional_orders_path(@location)
        assert_response :success
        assert_select "span", text: @bento_a.name
      end

      test "index page displays help messages" do
        login_as_employee(@employee)
        get pos_location_additional_orders_path(@location)
        assert_response :success
        assert_select ".alert-info", /LINE/
        assert_select ".alert-warning", /取り消し/
      end

      test "index page displays link to new order page" do
        login_as_employee(@employee)
        get pos_location_additional_orders_path(@location)
        assert_response :success
        assert_select "a[href='#{new_pos_location_additional_order_path(@location)}']"
      end

      # ============================================================
      # new アクションのテスト
      # ============================================================

      test "admin can access new page" do
        login_as_employee(@employee)
        get new_pos_location_additional_order_path(@location)
        assert_response :success
      end

      test "employee can access new page" do
        login_as_employee(@employee)
        get new_pos_location_additional_order_path(@location)
        assert_response :success
      end

      test "unauthenticated user is redirected to login on new" do
        get new_pos_location_additional_order_path(@location)
        assert_redirected_to "/employee/login"
      end

      test "new returns 404 for inactive location" do
        login_as_employee(@employee)
        inactive_location = locations(:prefectural_office)
        get new_pos_location_additional_order_path(inactive_location)
        assert_response :not_found
      end

      test "new page displays bento inventory items" do
        login_as_employee(@employee)
        get new_pos_location_additional_order_path(@location)
        assert_response :success
        assert_select "#order-item-#{@bento_a.id}"
      end

      test "new page does not display side menu items in order form" do
        login_as_employee(@employee)
        get new_pos_location_additional_order_path(@location)
        assert_response :success
        salad = catalogs(:salad)
        assert_select "#order-item-#{salad.id}", count: 0
      end

      # ============================================================
      # create アクションのテスト
      # ============================================================

      test "admin can create additional orders for multiple items" do
        login_as_employee(@employee)

        assert_difference "AdditionalOrder.count", 2 do
          post pos_location_additional_orders_path(@location),
               params: {
                 order: {
                   @bento_a.id.to_s => { quantity: "3" },
                   @bento_b.id.to_s => { quantity: "2" }
                 }
               }
        end

        assert_redirected_to pos_location_additional_orders_path(@location)
        follow_redirect!
        assert_select ".alert-success", /2件の追加発注を記録しました/
      end

      test "employee can create additional orders" do
        login_as_employee(@employee)

        assert_difference "AdditionalOrder.count", 1 do
          post pos_location_additional_orders_path(@location),
               params: {
                 order: {
                   @bento_a.id.to_s => { quantity: "5" }
                 }
               }
        end

        assert_redirected_to pos_location_additional_orders_path(@location)
      end

      test "create with single item and others at zero" do
        login_as_employee(@employee)

        assert_difference "AdditionalOrder.count", 1 do
          post pos_location_additional_orders_path(@location),
               params: {
                 order: {
                   @bento_a.id.to_s => { quantity: "3" },
                   @bento_b.id.to_s => { quantity: "0" }
                 }
               }
        end

        assert_redirected_to pos_location_additional_orders_path(@location)
      end

      test "create increments inventory stock" do
        login_as_employee(@employee)
        inventory = daily_inventories(:city_hall_bento_a_today)
        original_stock = inventory.stock

        post pos_location_additional_orders_path(@location),
             params: {
               order: {
                 @bento_a.id.to_s => { quantity: "5" }
               }
             }

        assert_equal original_stock + 5, inventory.reload.stock
      end

      test "create records current time automatically" do
        login_as_employee(@employee)

        freeze_time do
          post pos_location_additional_orders_path(@location),
               params: {
                 order: {
                   @bento_a.id.to_s => { quantity: "3" }
                 }
               }

          order = AdditionalOrder.last
          assert_in_delta Time.current, order.order_at, 1.second
        end
      end

      test "create records employee" do
        login_as_employee(@employee)

        post pos_location_additional_orders_path(@location),
             params: {
               order: {
                 @bento_a.id.to_s => { quantity: "2" }
               }
             }

        order = AdditionalOrder.last
        assert_equal @employee, order.employee
      end

      test "create fails when all quantities are zero" do
        login_as_employee(@employee)

        assert_no_difference "AdditionalOrder.count" do
          post pos_location_additional_orders_path(@location),
               params: {
                 order: {
                   @bento_a.id.to_s => { quantity: "0" },
                   @bento_b.id.to_s => { quantity: "0" }
                 }
               }
        end

        assert_response :unprocessable_entity
      end

      test "unauthenticated user is redirected to login on create" do
        post pos_location_additional_orders_path(@location)
        assert_redirected_to "/employee/login"
      end
    end
  end
end
