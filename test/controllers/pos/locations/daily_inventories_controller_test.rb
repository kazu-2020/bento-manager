# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    class DailyInventoriesControllerTest < ActionDispatch::IntegrationTest
      fixtures :employees, :locations, :catalogs, :catalog_discontinuations

      setup do
        @employee = employees(:verified_employee)
        @location = Location.create!(name: "テスト販売先", status: :active)
        @bento_a = catalogs(:daily_bento_a)
        @bento_b = catalogs(:daily_bento_b)
        @salad = catalogs(:salad)
      end

      # ============================================================
      # new アクションのテスト
      # ============================================================

      test "admin can access new page" do
        login_as_employee(@employee)
        get new_pos_location_daily_inventory_path(@location)
        assert_response :success
      end

      test "employee can access new page" do
        login_as_employee(@employee)
        get new_pos_location_daily_inventory_path(@location)
        assert_response :success
      end

      test "new page displays available bento catalogs" do
        login_as_employee(@employee)
        get new_pos_location_daily_inventory_path(@location)
        assert_response :success
        assert_select "span", text: @bento_a.name
      end

      test "new page displays available side menu catalogs" do
        login_as_employee(@employee)
        get new_pos_location_daily_inventory_path(@location)
        assert_response :success
        assert_select "span", text: @salad.name
      end

      test "new page does not display discontinued catalogs" do
        login_as_employee(@employee)
        discontinued_bento = catalogs(:discontinued_bento)
        CatalogDiscontinuation.create!(
          catalog: discontinued_bento,
          discontinued_at: Time.current,
          reason: "テスト用提供終了"
        )

        get new_pos_location_daily_inventory_path(@location)
        assert_response :success
        assert_select "span", text: discontinued_bento.name, count: 0
      end

      test "new page shows submit button disabled by default" do
        login_as_employee(@employee)
        get new_pos_location_daily_inventory_path(@location)
        assert_response :success
        assert_select "button[type='submit'][disabled]"
      end

      test "unauthenticated user is redirected to login on new" do
        get new_pos_location_daily_inventory_path(@location)
        assert_redirected_to "/employee/login"
      end

      test "new returns 404 for inactive location" do
        login_as_employee(@employee)
        inactive_location = locations(:prefectural_office)
        get new_pos_location_daily_inventory_path(inactive_location)
        assert_response :not_found
      end

      # ============================================================
      # refetch アクション (Ghost Form) のテスト
      # ============================================================

      test "refetch with selected item re-renders form with selection" do
        login_as_employee(@employee)

        post pos_location_daily_inventories_form_state_path(@location),
             params: {
               ghost_inventory: {
                 @bento_a.id.to_s => { selected: "1", stock: "10" },
                 @bento_b.id.to_s => { selected: "0", stock: "10" }
               }
             },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        assert_response :success
        assert_match "turbo-stream", response.body
        assert_match "inventory[#{@bento_a.id}][selected]", response.body
      end

      test "refetch with stock change re-renders form with new stock" do
        login_as_employee(@employee)

        post pos_location_daily_inventories_form_state_path(@location),
             params: {
               ghost_inventory: {
                 @bento_a.id.to_s => { selected: "1", stock: "15" }
               }
             },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        assert_response :success
        assert_match "turbo-stream", response.body
        assert_match 'value="15"', response.body
      end

      test "refetch enables submit button when item selected" do
        login_as_employee(@employee)

        post pos_location_daily_inventories_form_state_path(@location),
             params: {
               ghost_inventory: {
                 @bento_a.id.to_s => { selected: "1", stock: "10" }
               }
             },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        assert_response :success
        assert_match "turbo-stream", response.body
        # ボタンが有効化されている（disabled 属性がない）
        assert_no_match(/button.*disabled.*販売開始/, response.body)
      end

      # ============================================================
      # create アクションのテスト
      # ============================================================

      test "admin can create daily inventories via form" do
        login_as_employee(@employee)

        assert_difference "DailyInventory.count", 2 do
          post pos_location_daily_inventories_path(@location),
               params: {
                 inventory: {
                   @bento_a.id.to_s => { selected: "1", stock: "10" },
                   @bento_b.id.to_s => { selected: "1", stock: "5" }
                 }
               }
        end

        assert_redirected_to new_pos_location_sale_path(@location)
        follow_redirect!
        assert_select ".alert-success", /2種類/
      end

      test "employee can create daily inventories via form" do
        login_as_employee(@employee)

        assert_difference "DailyInventory.count", 1 do
          post pos_location_daily_inventories_path(@location),
               params: {
                 inventory: {
                   @bento_a.id.to_s => { selected: "1", stock: "10" }
                 }
               }
        end

        assert_redirected_to new_pos_location_sale_path(@location)
      end

      test "create fails when no items selected" do
        login_as_employee(@employee)

        assert_no_difference "DailyInventory.count" do
          post pos_location_daily_inventories_path(@location),
               params: {
                 inventory: {
                   @bento_a.id.to_s => { selected: "0", stock: "10" }
                 }
               }
        end

        assert_response :unprocessable_entity
      end

      test "create sets correct inventory_date to today" do
        login_as_employee(@employee)

        post pos_location_daily_inventories_path(@location),
             params: {
               inventory: {
                 @bento_a.id.to_s => { selected: "1", stock: "10" }
               }
             }

        inventory = DailyInventory.last
        assert_equal Date.current, inventory.inventory_date
      end

      test "create sets reserved_stock to zero" do
        login_as_employee(@employee)

        post pos_location_daily_inventories_path(@location),
             params: {
               inventory: {
                 @bento_a.id.to_s => { selected: "1", stock: "10" }
               }
             }

        inventory = DailyInventory.last
        assert_equal 0, inventory.reserved_stock
      end

      test "create uses stock value from form" do
        login_as_employee(@employee)

        post pos_location_daily_inventories_path(@location),
             params: {
               inventory: {
                 @bento_a.id.to_s => { selected: "1", stock: "25" }
               }
             }

        inventory = DailyInventory.last
        assert_equal 25, inventory.stock
      end

      test "create with side_menu items only" do
        login_as_employee(@employee)

        assert_difference "DailyInventory.count", 1 do
          post pos_location_daily_inventories_path(@location),
               params: {
                 inventory: {
                   @salad.id.to_s => { selected: "1", stock: "10" }
                 }
               }
        end

        assert_redirected_to new_pos_location_sale_path(@location)
        follow_redirect!
        assert_select ".alert-success", /1種類/
      end

      test "create with mixed bento and side_menu items" do
        login_as_employee(@employee)

        assert_difference "DailyInventory.count", 3 do
          post pos_location_daily_inventories_path(@location),
               params: {
                 inventory: {
                   @bento_a.id.to_s => { selected: "1", stock: "10" },
                   @bento_b.id.to_s => { selected: "1", stock: "5" },
                   @salad.id.to_s => { selected: "1", stock: "8" }
                 }
               }
        end

        assert_redirected_to new_pos_location_sale_path(@location)
        follow_redirect!
        assert_select ".alert-success", /3種類/
      end

      test "success message uses generic product term" do
        login_as_employee(@employee)

        post pos_location_daily_inventories_path(@location),
             params: {
               inventory: {
                 @bento_a.id.to_s => { selected: "1", stock: "10" }
               }
             }

        assert_redirected_to new_pos_location_sale_path(@location)
        follow_redirect!
        assert_select ".alert-success", text: /商品を登録しました/
      end

      test "unauthenticated user is redirected to login on create" do
        post pos_location_daily_inventories_path(@location)
        assert_redirected_to "/employee/login"
      end

      test "登録済みの場合、new アクションは修正ページにリダイレクトする" do
        login_as_employee(@employee)
        DailyInventory.create!(
          location: @location, catalog: @bento_a,
          inventory_date: Date.current, stock: 10, reserved_stock: 0
        )

        get new_pos_location_daily_inventory_path(@location)
        assert_redirected_to new_pos_location_daily_inventories_correction_path(@location)
      end
    end
  end
end
