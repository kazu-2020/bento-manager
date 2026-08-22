# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module DailyInventories
      # 再描画の中身は daily_inventories_controller_test.rb の refetch 群が見ている。
      # ここは PosLocationScoped が効いているかだけを確かめる
      class FormStatesControllerTest < ActionDispatch::IntegrationTest
        fixtures :employees, :locations, :catalogs

        setup do
          @location = locations(:city_hall)
          @bento_a = catalogs(:daily_bento_a)
          login_as_employee(:verified_employee)
        end

        test "未認証ユーザーはログインページにリダイレクトされる" do
          reset!

          post pos_location_daily_inventories_form_state_path(@location), params: ghost_params

          assert_redirected_to "/employee/login"
        end

        test "停止中の拠点では 404 になる" do
          post pos_location_daily_inventories_form_state_path(locations(:prefectural_office)),
               params: ghost_params

          assert_response :not_found
        end

        private

        def ghost_params
          { ghost_inventory: { @bento_a.id.to_s => { selected: "1", stock: "10" } } }
        end
      end
    end
  end
end
