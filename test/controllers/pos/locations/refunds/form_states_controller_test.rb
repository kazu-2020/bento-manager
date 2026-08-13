# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module Refunds
      class FormStatesControllerTest < ActionDispatch::IntegrationTest
        fixtures :employees, :locations, :catalogs, :catalog_prices, :catalog_pricing_rules,
                 :daily_inventories, :discounts, :coupons, :sales, :sale_items

        setup do
          @employee = employees(:verified_employee)
          @location = locations(:city_hall)
          @sale = sales(:completed_sale)
          @bento_a = catalogs(:daily_bento_a)
        end

        test "unauthenticated user is redirected to login" do
          post pos_location_refunds_form_state_path(@location), params: { sale_id: @sale.id }

          assert_redirected_to "/employee/login"
        end

        test "responds with turbo_stream format" do
          login_as_employee(@employee)

          post pos_location_refunds_form_state_path(@location),
               params: {
                 sale_id: @sale.id,
                 ghost_refund: {
                   corrected: { @bento_a.id.to_s => { quantity: "1" } }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "turbo-stream", response.body
        end

        test "構造が壊れた返品内容を送られても画面は通常どおり再描画される" do
          login_as_employee(@employee)

          post pos_location_refunds_form_state_path(@location),
               params: {
                 sale_id: @sale.id,
                 ghost_refund: {
                   corrected: "ハッシュではなく文字列",
                   coupon: [ "ハッシュではなく配列" ]
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "turbo-stream", response.body
        end
      end
    end
  end
end
