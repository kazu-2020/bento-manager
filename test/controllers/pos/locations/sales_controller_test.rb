# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    class SalesControllerTest < ActionDispatch::IntegrationTest
      fixtures :admins, :employees, :locations, :catalogs, :catalog_prices, :catalog_pricing_rules, :daily_inventories, :discounts, :coupons

      setup do
        @admin = admins(:verified_admin)
        @employee = employees(:verified_employee)
        @location = locations(:city_hall)
        @bento_a = catalogs(:daily_bento_a)
        @salad = catalogs(:salad)
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

      # ============================================================
      # create アクションのテスト
      # ============================================================

      test "admin can create a sale with bento" do
        login_as(@admin)

        assert_difference "Sale.count", 1 do
          assert_difference "SaleItem.count" do
            post pos_location_sales_path(@location),
                 params: {
                   cart: {
                     @bento_a.id.to_s => { quantity: "1" },
                     customer_type: "staff"
                   }
                 }
          end
        end

        assert_redirected_to new_pos_location_sale_path(@location)
        follow_redirect!
        assert_select ".alert-success", /販売を記録しました/
      end

      test "employee can create a sale" do
        login_as_employee(@employee)

        assert_difference "Sale.count", 1 do
          post pos_location_sales_path(@location),
               params: {
                 cart: {
                   @bento_a.id.to_s => { quantity: "1" },
                   customer_type: "citizen"
                 }
               }
        end

        assert_redirected_to new_pos_location_sale_path(@location)
      end

      test "create decrements inventory stock" do
        login_as(@admin)
        inventory = daily_inventories(:city_hall_bento_a_today)

        assert_difference -> { inventory.reload.stock }, -2 do
          post pos_location_sales_path(@location),
               params: {
                 cart: {
                   @bento_a.id.to_s => { quantity: "2" },
                   customer_type: "staff"
                 }
               }
        end
      end

      test "create with bento and salad applies bundle price" do
        login_as(@admin)

        post pos_location_sales_path(@location),
             params: {
               cart: {
                 @bento_a.id.to_s => { quantity: "1" },
                 @salad.id.to_s => { quantity: "1" },
                 customer_type: "staff"
               }
             }

        sale = Sale.last
        # 弁当550円 + サラダ150円（セット価格）= 700円
        assert_equal 700, sale.total_amount
        assert_equal 700, sale.final_amount
      end

      test "create with discount applied" do
        login_as(@admin)
        discount = discounts(:fifty_yen_discount)

        post pos_location_sales_path(@location),
             params: {
               cart: {
                 @bento_a.id.to_s => { quantity: "1" },
                 customer_type: "staff",
                 coupon: { discount.id.to_s => "1" }
               }
             }

        sale = Sale.last
        assert_equal 550, sale.total_amount
        assert_equal 500, sale.final_amount
        assert_equal 1, sale.sale_discounts.count
      end

      test "create fails without customer_type" do
        login_as(@admin)

        assert_no_difference "Sale.count" do
          post pos_location_sales_path(@location),
               params: {
                 cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               }
        end

        assert_response :unprocessable_entity
      end

      test "create fails without items in cart" do
        login_as(@admin)

        assert_no_difference "Sale.count" do
          post pos_location_sales_path(@location),
               params: {
                 cart: {
                   customer_type: "staff"
                 }
               }
        end

        assert_response :unprocessable_entity
      end

      test "create fails with insufficient stock" do
        login_as(@admin)
        inventory = daily_inventories(:city_hall_bento_a_today)

        assert_no_difference "Sale.count" do
          post pos_location_sales_path(@location),
               params: {
                 cart: {
                   @bento_a.id.to_s => { quantity: (inventory.stock + 100).to_s },
                   customer_type: "staff"
                 }
               }
        end

        assert_response :unprocessable_entity
      end

      test "unauthenticated user is redirected to login on create" do
        post pos_location_sales_path(@location)
        assert_redirected_to "/employee/login"
      end
    end
  end
end
