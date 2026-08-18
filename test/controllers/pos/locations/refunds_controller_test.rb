# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    class RefundsControllerTest < ActionDispatch::IntegrationTest
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
      # new アクションのテスト
      # ============================================================

      test "unauthenticated user is redirected to login on new" do
        get new_pos_location_refund_path(@location, sale_id: @sale.id)

        assert_redirected_to "/employee/login"
      end

      test "employee can access new page" do
        login_as_employee(@employee)
        get new_pos_location_refund_path(@location, sale_id: @sale.id)

        assert_response :success
      end

      test "差額精算の画面を開くと、修正カートには元の販売の数量とクーポン枚数が入る" do
        login_as_employee(@employee)
        get new_pos_location_refund_path(@location, sale_id: @sale.id)

        assert_response :success
        # 初回描画は未送信。ここを送信済みとして扱うと「キーの欠落 = 0」の規則が
        # 初回描画にも及び、画面を開いた瞬間に全額返金の見た目になる
        assert_select "input[name=?][value=?]",
                      "ghost_refund[corrected][#{@bento_a.id}][quantity]", "1"
        assert_select "input[name=?][value=?]",
                      "ghost_refund[coupon][#{@fifty_yen.id}][quantity]", "1"
      end

      test "new returns 404 for inactive location" do
        login_as_employee(@employee)
        get new_pos_location_refund_path(locations(:prefectural_office),
                                         sale_id: sales(:prefectural_office_sale).id)

        assert_response :not_found
      end

      test "new returns 404 for a sale belonging to another location" do
        login_as_employee(@employee)
        get new_pos_location_refund_path(@location, sale_id: sales(:prefectural_office_sale).id)

        assert_response :not_found
      end

      test "取消済みの販売を返品しようとすると販売履歴に戻される" do
        login_as_employee(@employee)
        get new_pos_location_refund_path(@location, sale_id: sales(:voided_sale).id)

        assert_redirected_to pos_location_sales_history_index_path(@location)
        assert_equal "この販売は既に取消済みです", flash[:alert]
      end

      # ============================================================
      # create アクションのテスト（差額の3分岐）
      # ============================================================

      test "全商品を0にすると全額が返金され販売が取り消される" do
        login_as_employee(@employee)
        inventory = daily_inventories(:city_hall_bento_a_today)

        assert_difference "Refund.count", 1 do
          assert_difference -> { inventory.reload.stock }, 1 do
            post_refund(corrected: { @bento_a => 0 }, coupon: { @fifty_yen => 0 })
          end
        end

        assert_redirected_to pos_location_sales_history_index_path(@location)
        assert_match "返金処理が完了しました", flash[:notice]

        refund = Refund.last

        assert_equal 500, refund.amount
        assert_nil refund.corrected_sale_id
        assert_predicate @sale.reload, :voided?
      end

      test "商品を追加すると差額が追加徴収として記録される" do
        login_as_employee(@employee)

        assert_difference "Refund.count", 1 do
          post_refund(
            corrected: { @bento_a => 1, @salad => 1 },
            coupon: { @fifty_yen => 1 }
          )
        end

        assert_redirected_to pos_location_sales_history_index_path(@location)
        assert_match "追加請求が完了しました", flash[:notice]

        # 弁当A(550) + サラダ(セット価格150) - クーポン50 = 650円
        # 差額: 500 - 650 = -150（追加徴収）
        assert_equal(-150, Refund.last.amount)
      end

      test "同額の商品に交換すると差額なしとして記録される" do
        login_as_employee(@employee)

        assert_difference "Refund.count", 1 do
          post_refund(
            corrected: { @bento_a => 0, @bento_b => 1 },
            coupon: { @fifty_yen => 0 }
          )
        end

        assert_redirected_to pos_location_sales_history_index_path(@location)
        assert_match "交換処理が完了しました", flash[:notice]

        # 弁当B(500円) - クーポンなし = 500円。元の会計と同額
        assert_equal 0, Refund.last.amount
      end

      test "弁当を0個にすると、修正後の販売にクーポンは適用されない" do
        login_as_employee(@employee)

        # 弁当が0個だとクーポンの枚数は入力できないため、送信ボディにクーポンは含まれない
        assert_difference "Refund.count", 1 do
          post_refund(corrected: { @bento_a => 0, @salad => 1 })
        end

        assert_redirected_to pos_location_sales_history_index_path(@location)

        corrected_sale = Refund.last.corrected_sale

        # サラダ単品は250円。弁当がないためセット価格150円にもならず、クーポンも適用できない
        assert_equal 250, corrected_sale.final_amount
        assert_empty corrected_sale.sale_discounts
        # 差額: 元の販売500円 - 修正後250円 = 250円の返金
        assert_equal 250, Refund.last.amount
      end

      # ============================================================
      # create アクションのテスト（異常系）
      # ============================================================

      test "商品数量もクーポン枚数も変更していない場合は差額精算できない" do
        login_as_employee(@employee)

        assert_no_difference "Refund.count" do
          post_refund(corrected: { @bento_a => 1 }, coupon: { @fifty_yen => 1 })
        end

        assert_response :unprocessable_entity
        assert_equal "商品数量またはクーポン枚数を変更してください", flash[:alert]
        assert_not_predicate @sale.reload, :voided?
      end

      test "修正後の数量が1件も読めない送信は、確定せずに差し戻される" do
        login_as_employee(@employee)

        # 修正カートの中身が1件も読めないなら、それは「全て0」ではなく壊れた送信。
        # 0として通すと修正後の販売が作られないまま元の販売が取り消され、全額返金になる
        assert_no_difference [ "Refund.count", "Sale.count" ] do
          post pos_location_refunds_path(@location),
               params: {
                 sale_id: @sale.id,
                 refund: {
                   corrected: "ハッシュではなく文字列",
                   coupon: { @fifty_yen.id.to_s => { quantity: "0" } }
                 }
               }
        end

        assert_response :unprocessable_entity
        assert_not_predicate @sale.reload, :voided?
        assert_equal "送信された内容を読み取れませんでした。画面を再読み込みしてやり直してください",
                     flash[:alert]
      end

      test "修正後の数量が読めない送信は、クーポンの有無で案内が変わらない" do
        login_as_employee(@employee)

        # 数量が読めない時点で「変更されたか」は判定しようがない。クーポンが
        # 付いていないだけで「変更してください」と案内しても直しようがない
        assert_no_difference "Refund.count" do
          post pos_location_refunds_path(@location),
               params: { sale_id: @sale.id, refund: { corrected: "ハッシュではなく文字列" } }
        end

        assert_response :unprocessable_entity
        assert_equal "送信された内容を読み取れませんでした。画面を再読み込みしてやり直してください",
                     flash[:alert]
      end

      test "refund キーの無い送信も、壊れた送信として差し戻される" do
        login_as_employee(@employee)

        # 名前空間ごと届かなかったのは「未送信」ではない。初回描画と同じに畳むと
        # 元の販売から初期値が組み直され、直しようのない「変更してください」になる
        assert_no_difference [ "Refund.count", "Sale.count" ] do
          post pos_location_refunds_path(@location), params: { sale_id: @sale.id }
        end

        assert_response :unprocessable_entity
        assert_not_predicate @sale.reload, :voided?
        assert_equal "送信された内容を読み取れませんでした。画面を再読み込みしてやり直してください",
                     flash[:alert]
      end

      # 葉が全滅した group を残すと `{"<id>" => {}}` が中身のある送信に見え、
      # Quantities.from が {id => 0} に落として全額返金まで通ってしまう
      test "数量の葉が全て捨てられた送信は、全て0ではなく壊れた送信として差し戻される" do
        login_as_employee(@employee)

        assert_no_difference [ "Refund.count", "Sale.count" ] do
          post pos_location_refunds_path(@location),
               params: {
                 sale_id: @sale.id,
                 refund: { corrected: { @bento_a.id.to_s => { quantity: { nested: "1" } } } }
               }
        end

        assert_response :unprocessable_entity
        assert_not_predicate @sale.reload, :voided?
        assert_equal "送信された内容を読み取れませんでした。画面を再読み込みしてやり直してください",
                     flash[:alert]
      end

      test "取消済みの販売に差額精算を送信しても処理されない" do
        login_as_employee(@employee)
        voided_sale = sales(:voided_sale)

        assert_no_difference "Refund.count" do
          post_refund(sale: voided_sale, corrected: { @bento_a => 0 })
        end

        assert_response :unprocessable_entity
        assert_equal "この販売は既に取消済みです", flash[:alert]
      end

      test "予約済み在庫を割り込む数量に交換すると差額精算全体が取り消される" do
        login_as_employee(@employee)
        # 弁当B: stock 5 / reserved 2 → 利用可能在庫 3
        inventory = daily_inventories(:city_hall_bento_b_today)

        assert_no_difference [ "Refund.count", "Sale.count" ] do
          assert_no_changes -> { inventory.reload.stock } do
            post_refund(
              corrected: { @bento_a => 0, @bento_b => 4 },
              coupon: { @fifty_yen => 0 }
            )
          end
        end

        assert_response :unprocessable_entity
        assert_not_predicate @sale.reload, :voided?
        assert_match "利用可能在庫数", flash[:alert]
      end

      test "unauthenticated user is redirected to login on create" do
        post pos_location_refunds_path(@location), params: { sale_id: @sale.id }

        assert_redirected_to "/employee/login"
      end

      private

      # 差額精算の確定を送信する
      #
      # @param sale [Sale] 対象の販売（既定は @sale）
      # @param corrected [Hash{Catalog => Integer}] 修正後の商品数量
      # @param coupon [Hash{Discount => Integer}] 修正後のクーポン枚数
      def post_refund(sale: @sale, corrected: {}, coupon: {})
        post pos_location_refunds_path(@location),
             params: {
               sale_id: sale.id,
               refund: refund_quantity_params(corrected:, coupon:)
             }
      end
    end
  end
end
