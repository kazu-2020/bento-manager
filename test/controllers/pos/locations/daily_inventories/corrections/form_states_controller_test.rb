# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module DailyInventories
      module Corrections
        class FormStatesControllerTest < ActionDispatch::IntegrationTest
          fixtures :employees, :locations, :catalogs

          setup do
            @location = locations(:city_hall)
            @bento_a = catalogs(:daily_bento_a)
            login_as_employee(:verified_employee)
          end

          test "未認証ユーザーはログインページにリダイレクトされる" do
            reset!

            post pos_location_daily_inventories_corrections_form_state_path(@location), params: ghost_params

            assert_redirected_to "/employee/login"
          end

          test "停止中の拠点では 404 になる" do
            post pos_location_daily_inventories_corrections_form_state_path(locations(:prefectural_office)),
                 params: ghost_params

            assert_response :not_found
          end

          test "稼働中の拠点では Ghost Form が再描画される" do
            post pos_location_daily_inventories_corrections_form_state_path(@location),
                 params: ghost_params,
                 as: :turbo_stream

            assert_response :success
            assert_match "turbo-stream", response.body
            assert_match "inventory[#{@bento_a.id}][selected]", response.body
          end

          private

          def ghost_params
            { ghost_inventory: { @bento_a.id.to_s => { selected: "1", stock: "10" } } }
          end
        end
      end
    end
  end
end
