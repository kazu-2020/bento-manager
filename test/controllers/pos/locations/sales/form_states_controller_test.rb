# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module Sales
      class FormStatesControllerTest < ActionDispatch::IntegrationTest
        fixtures :admins, :employees, :locations, :catalogs, :catalog_prices, :catalog_pricing_rules, :daily_inventories, :discounts, :coupons

        setup do
          @admin = admins(:verified_admin)
          @employee = employees(:verified_employee)
          @location = locations(:city_hall)
          @bento_a = catalogs(:daily_bento_a)
          @salad = catalogs(:salad)
        end

        # ============================================================
        # 認証テスト
        # ============================================================

        test "unauthenticated user is redirected to login" do
          post pos_location_sales_form_state_path(@location)
          assert_redirected_to "/employee/login"
        end

        # ============================================================
        # Turbo Stream レスポンステスト
        # ============================================================

        test "responds with turbo_stream format" do
          login_as(@admin)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "turbo-stream", response.body
        end

        test "returns updated product card for item with quantity" do
          login_as(@admin)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "2" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "cart-item-#{@bento_a.id}", response.body
        end

        test "returns updated price breakdown" do
          login_as(@admin)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "price-breakdown", response.body
        end

        test "returns updated ghost form" do
          login_as(@admin)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "3" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "ghost-form", response.body
        end

        test "returns updated coupon section" do
          login_as(@admin)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "coupon-section", response.body
        end

        test "returns updated submit button" do
          login_as(@admin)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" },
                   customer_type: "staff"
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "sale-submit-button", response.body
        end

        test "employee can access form state" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
        end

        test "returns 404 for inactive location" do
          login_as(@admin)
          inactive_location = locations(:prefectural_office)

          post pos_location_sales_form_state_path(inactive_location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :not_found
        end
      end
    end
  end
end
