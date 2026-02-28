# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module AdditionalOrders
      class FormStatesControllerTest < ActionDispatch::IntegrationTest
        fixtures :employees, :locations, :catalogs, :daily_inventories

        setup do
          @employee = employees(:verified_employee)
          @location = locations(:city_hall)
          @bento_a = catalogs(:daily_bento_a)
        end

        test "unauthenticated user is redirected to login" do
          post pos_location_additional_orders_form_state_path(@location)
          assert_redirected_to "/employee/login"
        end

        test "responds with turbo_stream format" do
          login_as_employee(@employee)

          post pos_location_additional_orders_form_state_path(@location),
               params: {
                 ghost_order: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "turbo-stream", response.body
        end

        test "returns updated order item cards" do
          login_as_employee(@employee)

          post pos_location_additional_orders_form_state_path(@location),
               params: {
                 ghost_order: {
                   @bento_a.id.to_s => { quantity: "2" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "order-item-#{@bento_a.id}", response.body
        end

        test "returns updated ghost form" do
          login_as_employee(@employee)

          post pos_location_additional_orders_form_state_path(@location),
               params: {
                 ghost_order: {
                   @bento_a.id.to_s => { quantity: "3" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "ghost-form", response.body
        end

        test "検索クエリで商品を絞り込める" do
          login_as_employee(@employee)
          bento_b = catalogs(:daily_bento_b)

          post pos_location_additional_orders_form_state_path(@location),
               params: { search_query: "弁当A" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "order-item-#{@bento_a.id}", response.body
          assert_match(/id="order-item-#{bento_b.id}"[^>]*class="hidden"/, response.body)
        end

        test "returns 404 for inactive location" do
          login_as_employee(@employee)
          inactive_location = locations(:prefectural_office)

          post pos_location_additional_orders_form_state_path(inactive_location),
               params: {
                 ghost_order: {
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
