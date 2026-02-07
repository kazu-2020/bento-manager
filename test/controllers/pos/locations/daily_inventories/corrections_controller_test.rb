# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module DailyInventories
      class CorrectionsControllerTest < ActionDispatch::IntegrationTest
        fixtures :employees, :locations, :catalogs, :catalog_discontinuations

        setup do
          @employee = employees(:verified_employee)
          @location = Location.create!(name: "修正テスト販売先", status: :active)
          @bento_a = catalogs(:daily_bento_a)
          @bento_b = catalogs(:daily_bento_b)
          @salad = catalogs(:salad)
        end

        test "修正ページに既存の在庫数がプリフィルされる" do
          login_as_employee(@employee)
          DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 10, reserved_stock: 0
          )
          DailyInventory.create!(
            location: @location, catalog: @bento_b,
            inventory_date: Date.current, stock: 5, reserved_stock: 0
          )

          get new_pos_location_daily_inventories_correction_path(@location)
          assert_response :success
          assert_match 'value="10"', response.body
          assert_match 'value="5"', response.body
        end

        test "在庫を再登録するとレコードが削除→再作成される" do
          login_as_employee(@employee)
          DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 10, reserved_stock: 0
          )

          assert_no_difference "DailyInventory.count" do
            post pos_location_daily_inventories_correction_path(@location),
                 params: {
                   inventory: {
                     @bento_a.id.to_s => { selected: "1", stock: "20" }
                   }
                 }
          end

          assert_redirected_to new_pos_location_sale_path(@location)

          recreated = DailyInventory.find_by(location: @location, catalog: @bento_a, inventory_date: Date.current)
          assert_equal 20, recreated.stock
          assert_equal 0, recreated.lock_version
        end

        test "販売開始後の再登録はエラーメッセージを表示する" do
          login_as_employee(@employee)
          inventory = DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 10, reserved_stock: 0
          )
          inventory.decrement_stock!(1)

          post pos_location_daily_inventories_correction_path(@location),
               params: {
                 inventory: {
                   @bento_a.id.to_s => { selected: "1", stock: "20" }
                 }
               }

          assert_response :unprocessable_entity
          assert_match "販売が開始されているため", response.body
        end

        test "登録がない場合は新規登録ページにリダイレクトされる" do
          login_as_employee(@employee)

          get new_pos_location_daily_inventories_correction_path(@location)
          assert_redirected_to new_pos_location_daily_inventory_path(@location)
        end
      end
    end
  end
end
