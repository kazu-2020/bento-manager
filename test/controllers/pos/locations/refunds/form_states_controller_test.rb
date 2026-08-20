# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module Refunds
      class FormStatesControllerTest < ActionDispatch::IntegrationTest
        include RefundParamsHelper
        include QueryCountHelper

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

        # 返却クーポンの案内は元の販売のクーポンを 1 枚ずつ読む。数量入力を動かすたびに
        # この経路が再描画されるため、クーポンごとに問い合わせが増える形になっていると
        # 操作のたびに積み上がる。RefundFormBuildable#set_sale の preload がそれを防ぐ
        test "修正カートの再描画は元の販売のクーポンが増えても問い合わせ本数が増えない" do
          login_as_employee(@employee)
          more_coupons = -> do
            SaleDiscount.create!(
              sale: @sale,
              discount: discounts(:hundred_yen_discount),
              discount_amount: 100,
              quantity: 1
            )
          end

          assert_queries_unaffected_by(more_coupons, "元の販売のクーポンごとに読み込みが走っている") do
            # クーポンを 0 枚に減らした送信。返却クーポンの算出まで通す
            post_form_state(corrected: { @bento_a => 1 }, coupon: {})
          end
        end

        # クーポンカードは 1 枚ごとに discount.discountable を読む。有効なクーポンの
        # 種類が増えるたびに coupons への問い合わせが増える形になっていると、
        # 数量入力を動かすたびの再描画でその本数がまるごと乗る
        test "修正カートの再描画は有効なクーポンの種類が増えても問い合わせ本数が増えない" do
          login_as_employee(@employee)
          more_discounts = -> do
            Discount.create!(
              discountable: Coupon.new(amount_per_unit: 80),
              name: "80円割引クーポン",
              valid_from: 1.month.ago.to_date
            )
          end

          assert_queries_unaffected_by(more_discounts, "有効なクーポンごとに読み込みが走っている") do
            post_form_state(corrected: { @bento_a => 1 }, coupon: {})
          end
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
          post_form_state(location: locations(:prefectural_office), sale: sales(:prefectural_office_sale))

          assert_response :not_found
        end

        test "returns 404 for a sale belonging to another location" do
          login_as_employee(@employee)
          post_form_state(sale: sales(:prefectural_office_sale))

          assert_response :not_found
        end

        test "先に精算された販売の画面から送信しても、修正カートは描き直されず販売履歴に戻される" do
          login_as_employee(@employee)

          # 画面を開いたまま別の端末で精算された状況
          post_form_state(sale: sales(:voided_sale), corrected: { @bento_a => 0 })

          assert_redirected_to pos_location_sales_history_index_path(@location)
          assert_equal "この販売は既に取消済みです", flash[:alert]
        end

        test "日付が変わった後の画面から送信しても、修正カートは描き直されず販売履歴に戻される" do
          login_as_employee(@employee)
          @sale.update!(sale_datetime: 1.day.ago)

          post_form_state(corrected: { @bento_a => 0 })

          assert_redirected_to pos_location_sales_history_index_path(@location)
          assert_equal "差額精算は当日の販売のみ行えます", flash[:alert]
        end

        # ============================================================
        # Turbo Stream レスポンステスト
        # ============================================================

        test "replaces every region the refund screen depends on" do
          login_as_employee(@employee)
          post_form_state(corrected: { @bento_a => 0 }, coupon: { @fifty_yen => 0 })

          [
            "corrected-item-#{@bento_a.id}",
            "refund-preview",
            "refund-coupon-card-#{@fifty_yen.id}",
            "refund-submit-button",
            "ghost-form"
          ].each do |target|
            assert_turbo_stream action: "replace", target: target
          end
        end

        test "構造が壊れた返品内容を送られると、元の販売の数量に戻さず全て0で再描画される" do
          login_as_employee(@employee)

          post pos_location_refunds_form_state_path(@location, sale_id: @sale.id),
               params: {
                 ghost_refund: {
                   corrected: "ハッシュではなく文字列",
                   coupon: [ "ハッシュではなく配列" ]
                 }
               },
               as: :turbo_stream

          # 元の販売の数量に戻すと、壊れた送信が「変更なし」に見えてしまう
          assert_turbo_stream action: "replace", target: "ghost-form" do
            assert_select "input[name=?][value=?]",
                          "ghost_refund[corrected][#{@bento_a.id}][quantity]", "0"
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
          assert_turbo_stream action: "replace", target: "refund-preview" do
            assert_select ".text-4xl", text: "¥500"
          end
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
          assert_turbo_stream action: "replace", target: "refund-preview" do
            assert_select ".text-4xl", text: "¥150"
          end
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

          assert_turbo_stream action: "replace", target: "ghost-form" do
            assert_select "template input[name=?][value=?]",
                          "ghost_refund[corrected][#{@bento_a.id}][quantity]", "0"
            assert_select "template input[name=?][value=?]",
                          "ghost_refund[corrected][#{@bento_b.id}][quantity]", "2"
            assert_select "template input[name=?][value=?]",
                          "ghost_refund[coupon][#{@fifty_yen.id}][quantity]", "0"
          end
        end

        private

        # Ghost Form の送信を組み立てる
        #
        # sale_id は実際の Ghost Form と同じくクエリで渡す
        # （app/views/components/pos/refunds/ghost_form/component.rb 参照）
        #
        # @param location [Location] 販売先（既定は @location）
        # @param sale [Sale] 対象の販売（既定は @sale）
        # @param corrected [Hash{Catalog => Integer}] 修正後の商品数量
        # @param coupon [Hash{Discount => Integer}] 修正後のクーポン枚数
        def post_form_state(location: @location, sale: @sale, corrected: {}, coupon: {})
          post pos_location_refunds_form_state_path(location, sale_id: sale.id),
               params: { ghost_refund: refund_quantity_params(corrected:, coupon:) },
               as: :turbo_stream
        end
      end
    end
  end
end
