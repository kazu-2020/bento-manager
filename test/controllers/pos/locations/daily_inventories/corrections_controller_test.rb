# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module DailyInventories
      class CorrectionsControllerTest < ActionDispatch::IntegrationTest
        include SaleTestHelper

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

        test "在庫を訂正するとレコードが削除→再作成される" do
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
        end

        test "販売開始後の訂正はエラーメッセージを表示する" do
          login_as_employee(@employee)
          DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 10, reserved_stock: 0
          )
          start_sale

          post pos_location_daily_inventories_correction_path(@location),
               params: {
                 inventory: {
                   @bento_a.id.to_s => { selected: "1", stock: "20" }
                 }
               }

          assert_response :unprocessable_entity
          assert_match "販売が開始されているため", response.body
        end

        test "販売開始後は修正ページを開かず販売ページへリダイレクトされる" do
          login_as_employee(@employee)
          DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 10, reserved_stock: 0
          )
          start_sale

          get new_pos_location_daily_inventories_correction_path(@location)

          assert_redirected_to new_pos_location_sale_path(@location)
        end

        test "追加発注をしただけなら訂正ページを開け、追加発注込みの在庫と内訳が表示される" do
          login_as_employee(@employee)
          DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 20, reserved_stock: 0
          )
          AdditionalOrder.create_with_inventory!(
            location: @location, catalog_id: @bento_a.id,
            quantity: 5, order_at: Time.current
          )
          get new_pos_location_daily_inventories_correction_path(@location)

          assert_response :success
          assert_match 'value="25"', response.body
          assert_match "本日の追加発注", response.body
          assert_match "#{@bento_a.name} +5個", response.body
        end

        test "提供終了した商品でも当日在庫があれば訂正画面に出て、訂正しても在庫が残る" do
          login_as_employee(@employee)
          DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 20, reserved_stock: 0
          )
          discontinued = catalogs(:discontinued_bento)
          DailyInventory.create!(
            location: @location, catalog: discontinued,
            inventory_date: Date.current, stock: 3, reserved_stock: 0
          )
          CatalogDiscontinuation.create!(
            catalog: discontinued, discontinued_at: Time.current, reason: "提供終了"
          )

          get new_pos_location_daily_inventories_correction_path(@location)

          assert_response :success
          assert_match(/#{discontinued.name}/, response.body)
          assert_match 'value="3"', response.body

          post pos_location_daily_inventories_correction_path(@location),
               params: {
                 inventory: {
                   @bento_a.id.to_s => { selected: "1", stock: "20" },
                   discontinued.id.to_s => { selected: "1", stock: "3" }
                 }
               }

          assert_redirected_to new_pos_location_sale_path(@location)

          remaining = DailyInventory.find_by(
            location: @location, catalog: discontinued, inventory_date: Date.current
          )

          assert_equal 3, remaining.stock
        end

        test "訂正したあとは、それ以前の追加発注を内訳に出さない" do
          login_as_employee(@employee)

          travel_to Time.zone.parse("2026-08-18 08:00:00") do
            DailyInventory.create!(
              location: @location, catalog: @bento_a,
              inventory_date: Date.current, stock: 20, reserved_stock: 0
            )
          end

          travel_to Time.zone.parse("2026-08-18 09:00:00") do
            AdditionalOrder.create_with_inventory!(
              location: @location, catalog_id: @bento_a.id,
              quantity: 5, order_at: Time.current
            )
          end

          travel_to Time.zone.parse("2026-08-18 09:10:00") do
            post pos_location_daily_inventories_correction_path(@location),
                 params: { inventory: { @bento_a.id.to_s => { selected: "1", stock: "20" } } }

            assert_redirected_to new_pos_location_sale_path(@location)
          end

          travel_to Time.zone.parse("2026-08-18 09:20:00") do
            get new_pos_location_daily_inventories_correction_path(@location)

            assert_response :success
            assert_match 'value="20"', response.body
            assert_no_match(/本日の追加発注/, response.body)
          end
        end

        test "追加発注がなければ内訳は表示されない" do
          login_as_employee(@employee)
          DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 10, reserved_stock: 0
          )

          get new_pos_location_daily_inventories_correction_path(@location)

          assert_response :success
          assert_no_match "本日の追加発注", response.body
        end

        test "不正なパラメータだけの訂正は既存の在庫を作り直さずエラーになる" do
          login_as_employee(@employee)
          existing = DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 10, reserved_stock: 3
          )

          assert_no_changes -> { existing.reload.attributes } do
            post pos_location_daily_inventories_correction_path(@location),
                 params: { inventory: { "abc" => { selected: "1", stock: "1" } } }
          end

          assert_response :unprocessable_entity
          # 返品と同じ「読み取れなかった」案内。「商品を選択してください」ではない
          assert_match "送信された内容を読み取れませんでした", response.body
        end

        # inventory キーが丸ごと無い POST を「未送信」と読むと、既存在庫からの再構築に
        # 化けて bulk_recreate が走り、reserved_stock ごと作り直されてしまう
        test "inventory キーの無い訂正は既存の在庫を作り直さずエラーになる" do
          login_as_employee(@employee)
          existing = DailyInventory.create!(
            location: @location, catalog: @bento_a,
            inventory_date: Date.current, stock: 10, reserved_stock: 3
          )

          assert_no_changes -> { existing.reload.attributes } do
            post pos_location_daily_inventories_correction_path(@location)
          end

          assert_response :unprocessable_entity
          assert_match "送信された内容を読み取れませんでした", response.body
        end

        test "登録がない場合は新規登録ページにリダイレクトされる" do
          login_as_employee(@employee)

          get new_pos_location_daily_inventories_correction_path(@location)

          assert_redirected_to new_pos_location_daily_inventory_path(@location)
        end

        private

        def start_sale
          create_sale(location: @location, customer_type: :staff, sale_datetime: Time.current)
        end
      end
    end
  end
end
