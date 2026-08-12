# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module Refunds
      class FormStatesControllerTest < ActionDispatch::IntegrationTest
        include RefundParamsHelper

        fixtures :employees, :locations, :catalogs, :catalog_prices, :catalog_pricing_rules,
                 :daily_inventories, :discounts, :coupons, :sales, :sale_items, :sale_discounts

        setup do
          @employee = employees(:verified_employee)
          @location = locations(:city_hall)
          # 弁当A x1(550円) - 50円クーポン1枚 = 500円
          @sale = sales(:completed_sale)
          @bento_a = catalogs(:daily_bento_a)
          @bento_b = catalogs(:daily_bento_b)
          @salad = catalogs(:salad)
          @fifty_yen = discounts(:fifty_yen_discount)
        end

        # ============================================================
        # 認証・リソース解決
        # ============================================================

        test "unauthenticated user is redirected to login" do
          post pos_location_refunds_form_state_path(@location, sale_id: @sale.id)

          assert_redirected_to "/employee/login"
        end

        test "returns 404 for inactive location" do
          login_as_employee(@employee)
          post_form_state(location: locations(:prefectural_office))

          assert_response :not_found
        end

        test "returns 404 for a sale belonging to another location" do
          login_as_employee(@employee)
          post_form_state(sale: sales(:prefectural_office_sale))

          assert_response :not_found
        end

        # ============================================================
        # Turbo Stream レスポンステスト
        # ============================================================

        test "replaces every region the refund screen depends on" do
          login_as_employee(@employee)
          post_form_state(corrected: { @bento_a => 0 }, coupon: { @fifty_yen => 0 })

          assert_response :success

          [
            "corrected-item-#{@bento_a.id}",
            "refund-preview",
            "refund-coupon-card-#{@fifty_yen.id}",
            "refund-submit-button",
            "ghost-form"
          ].each do |target|
            assert_equal 1, turbo_stream_targets.count(target),
                         "turbo_stream に #{target} の置き換えが1件含まれること"
          end
        end

        # ============================================================
        # サーバーサイド再計算
        # ============================================================

        test "商品を0にすると精算内容が返金として再計算される" do
          login_as_employee(@employee)
          post_form_state(corrected: { @bento_a => 0 }, coupon: { @fifty_yen => 0 })

          assert_response :success
          assert_match "返金額", response.body
          assert_match "¥500", response.body
        end

        test "商品を追加すると精算内容が追加徴収として再計算される" do
          login_as_employee(@employee)
          post_form_state(
            corrected: { @bento_a => 1, @salad => 1 },
            coupon: { @fifty_yen => 1 }
          )

          assert_response :success
          # 弁当A(550) + サラダ(セット価格150) - クーポン50 = 650円。元の会計との差額150円
          assert_match "追加請求額", response.body
          assert_match "¥150", response.body
        end

        test "同額の商品に交換すると差額なしと再計算される" do
          login_as_employee(@employee)
          post_form_state(
            corrected: { @bento_a => 0, @bento_b => 1 },
            coupon: { @fifty_yen => 0 }
          )

          assert_response :success
          assert_match "差額なし", response.body
        end

        test "再描画された Ghost Form は送信した数量を保持する" do
          login_as_employee(@employee)
          post_form_state(corrected: { @bento_a => 0, @bento_b => 2 }, coupon: { @fifty_yen => 0 })

          assert_response :success
          assert_equal "0", ghost_form_value("ghost_refund[corrected][#{@bento_a.id}][quantity]")
          assert_equal "2", ghost_form_value("ghost_refund[corrected][#{@bento_b.id}][quantity]")
          assert_equal "0", ghost_form_value("ghost_refund[coupon][#{@fifty_yen.id}][quantity]")
        end

        private

        # Ghost Form の送信を組み立てる
        #
        # @param location [Location] 販売先（既定は @location）
        # @param sale [Sale] 対象の販売（既定は @sale）
        # @param corrected [Hash{Catalog => Integer}] 修正後の商品数量
        # @param coupon [Hash{Discount => Integer}] 修正後のクーポン枚数
        def post_form_state(location: @location, sale: @sale, corrected: {}, coupon: {})
          post pos_location_refunds_form_state_path(location, sale_id: sale.id),
               params: { ghost_refund: refund_quantity_params(corrected:, coupon:) },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        end

        # レスポンスに含まれる turbo_stream の置き換え対象 ID
        #
        # @return [Array<String>]
        def turbo_stream_targets
          response_document.css("turbo-stream[action='replace']").map { |el| el["target"] }
        end

        # 再描画された Ghost Form の hidden field の値
        #
        # @param name [String] input の name 属性
        # @return [String, nil]
        def ghost_form_value(name)
          response_document
            .at_css("turbo-stream[target='ghost-form'] template input[name='#{name}']")
            &.[]("value")
        end

        def response_document
          Nokogiri::HTML5.fragment(response.body)
        end
      end
    end
  end
end
