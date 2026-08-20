# frozen_string_literal: true

require "application_system_test_case"

module Pos
  class SalesTest < ApplicationSystemTestCase
    # :sales を必ず宣言する。sales_started_today? が在庫訂正バナーの有無を左右し
    # （sales_controller.rb:14）、宣言しないとバナーが出るが、他のテストクラスが
    # :sales を宣言していれば消える。単体実行と全体実行で画面が変わってしまう
    fixtures :employees, :locations, :catalogs, :catalog_prices, :catalog_pricing_rules,
             :daily_inventories, :discounts, :coupons, :sales

    setup do
      @location = locations(:city_hall)
      @bento_a = catalogs(:daily_bento_a)
    end

    # Ghost Form の配線（メインフォームと ghost_ 付き input の対応、stepper から
    # ghost-form#submit までの data-action、turbo_stream の target と DOM の id の
    # 一致、確定までの一連）は、実ブラウザでしか一度に通せない。
    # コントローラテストはパラメータを手書きして POST するので、どれも通らない。
    test "弁当の数量を増やすたびに価格内訳が更新され、そのまま販売を確定できる" do
      login_as_employee(:verified_employee)

      visit new_pos_location_sale_path(@location)

      within "#cart-item-#{@bento_a.id}" do
        click_on "増やす"
      end

      assert_selector "#price-breakdown", text: "¥550"

      # 2 回目は「最初の更新のあとも操作が効き続けるか」を見る。開発中、Chrome の
      # パスワード保存バブルが合成マウス入力を飲み、1 回目だけ通って以降が無言で
      # 死ぬ状態を実際にここで検出した（対処は application_system_test_case.rb）。
      #
      # なお Ghost Form の hidden が古いまま残る事態（ghost-form-pattern.md ルール6）は
      # ここでは検出できない。ghost_form_controller.js が毎回メインフォームの FormData で
      # 上書きするため、古い値は残らないため。ルール6 は form_states_controller_test.rb が
      # turbo_stream の内容として直接検証している
      within "#cart-item-#{@bento_a.id}" do
        click_on "増やす"
      end

      assert_selector "#price-breakdown", text: "¥1,100"

      # 顧客区分はメインフォームだけが持ち、Ghost Form の再描画では動かない。
      # 既定の「関係者」から変えることで、確定に載るのがメインフォームの値だと分かる
      choose "一般", allow_label_click: true

      # 件数と顧客区分を 1 つのアサーションで見る。別々に見ると「確定したのはどれか」を
      # id や時刻で突き止める必要が出るが、当日の販売はフィクスチャにも居る。
      # 在庫が減ることは Sales::Recorder のテストが見るので、ここでは踏まない
      assert_difference -> { @location.sales.completed.citizen.count }, 1 do
        click_on "¥1,100 を販売確定"

        assert_text "販売を記録しました"
      end
    end
  end
end
