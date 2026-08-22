# frozen_string_literal: true

require "application_system_test_case"

module Pos
  class RefundsTest < ApplicationSystemTestCase
    # :sales は POS の画面を扱う system テストの必須宣言（.claude/rules/testing.md ルール8）。
    # 差額精算は元の販売の明細とクーポンから初期値を組むため、:sale_items と
    # :sale_discounts も要る。これが欠けると修正カートが空の販売を精算することになる
    fixtures :employees, :locations, :catalogs, :catalog_prices, :catalog_pricing_rules,
             :daily_inventories, :discounts, :coupons, :sales, :sale_items, :sale_discounts

    setup do
      @location = locations(:city_hall)
      # 弁当A x1(550円) - 50円クーポン1枚 = 500円
      @sale = sales(:completed_sale)
      @bento_a = catalogs(:daily_bento_a)
    end

    # 差額精算も販売と同じ Ghost Form パターンだが、配線は別々の ERB とコントローラーで
    # 組まれている（数量入力は change->refund-cart#toggle、再描画の target は
    # corrected-item-* / refund-preview / refund-submit-button）。販売画面の system テストが
    # 通っても、こちらが生きている保証にはならない。
    #
    # 入力名の対応（メインフォームと ghost_ 付き input）はブラウザを使わずに守れるので、
    # ここでは踏まない。new_page_component_test.rb の assert_ghost_inputs_correspond が見る
    test "弁当の数量を増やすたびに精算内容が更新され、そのまま追加請求を確定できる" do
      login_as_employee(:verified_employee)

      visit new_pos_location_refund_path(@location, sale_id: @sale.id)

      # 修正カートに手が入るまで精算内容は描かれず、確定もできない。ここを固定しないと、
      # 次のアサーションが「最初から出ていた」のか「差し替えが届いた」のか区別できない
      assert_selector "#refund-submit-button button[disabled]"
      assert_no_selector "#refund-preview *"

      within "#corrected-item-#{@bento_a.id}" do
        click_on "増やす"
      end

      # 弁当A x2(1,100円) - クーポン50円 = 1,050円。元の会計 500 円との差額は 550 円の追加請求
      assert_selector "#refund-preview", text: "追加請求額"
      assert_selector "#refund-preview", text: "¥550"

      # 2 回目は「最初の更新のあとも操作が効き続けるか」を見る。数量入力は turbo_stream で
      # corrected-item-* ごと差し替わるため、差し替え後の input にも data-action が
      # 載っていなければここで止まる
      within "#corrected-item-#{@bento_a.id}" do
        click_on "増やす"
      end

      # 見るのは追加請求額（¥1,100）ではなく修正後合計。追加請求額は 1 回目の更新で
      # 描かれた明細（弁当A x2 = ¥1,100）と同じ文字列になるため、2 回目が無言で
      # 効かなくても素通りしてしまう
      assert_selector "#refund-preview", text: "¥1,600"

      # ボタンの文言は差額の向きで変わる。押せる文言になっていること自体が、
      # refund-submit-button の差し替えが届いた証拠になる
      assert_difference -> { Refund.count }, 1 do
        click_on "追加請求を確定"

        assert_text "追加請求が完了しました"
      end
    end
  end
end
