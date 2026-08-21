# frozen_string_literal: true

require "test_helper"

module Pos
  module Locations
    module Sales
      class FormStatesControllerTest < ActionDispatch::IntegrationTest
        include QueryCountHelper
        include StockedCatalogHelper
        include ActiveCouponHelper

        fixtures :employees, :locations, :catalogs, :catalog_prices, :catalog_pricing_rules, :daily_inventories, :discounts, :coupons

        setup do
          @employee = employees(:verified_employee)
          @location = locations(:city_hall)
          @bento_a = catalogs(:daily_bento_a)
          @salad = catalogs(:salad)
        end

        # ============================================================
        # 認証テスト
        # ============================================================

        test "unauthenticated user is redirected to login" do
          post pos_location_sales_form_state_path(@location)

          assert_redirected_to "/employee/login"
        end

        # ============================================================
        # Turbo Stream レスポンステスト
        # ============================================================

        test "入力を受けた再描画でも、価格の問い合わせは商品の数によらず1回で済む" do
          login_as_employee(@employee)

          # 入力のたびに POST が飛ぶ画面なので、カード 1 枚ごとの問い合わせがそのまま効いてくる
          assert_operator @location.today_inventories.count, :>=, 2

          assert_queries_match(/FROM ["`]catalog_prices["`]/, count: 1) do
            post pos_location_sales_form_state_path(@location),
                 params: { ghost_cart: { @bento_a.id.to_s => { quantity: "1" } } },
                 headers: { "Accept" => "text/vnd.turbo-stream.html" }
          end

          assert_response :success
        end

        # クーポンカードは 1 枚ごとに discount.discountable を読む。数量入力を動かすたびに
        # この経路が再描画されるため、有効なクーポンの種類ごとに問い合わせが増える形に
        # なっていると、操作のたびにその本数がまるごと乗る
        test "入力を受けた再描画は有効なクーポンの種類が増えても問い合わせ本数が増えない" do
          login_as_employee(@employee)
          more_coupon_types = -> { create_active_coupon }

          assert_queries_unaffected_by(more_coupon_types, "有効なクーポンごとに読み込みが走っている") do
            post pos_location_sales_form_state_path(@location),
                 params: { ghost_cart: { @bento_a.id.to_s => { quantity: "1" } } },
                 headers: { "Accept" => "text/vnd.turbo-stream.html" }

            # 経路が生きていることまで固定しないとガードが空振りする
            assert_response :success
          end
        end

        # 価格の再計算はカートの商品 1 種類ごとに価格ルールを引く。数量を動かすたびに
        # この経路が再描画されるため、種類ごとに問い合わせが増える形になっていると
        # 操作のたびにその本数がまるごと乗る
        test "入力を受けた再描画は、カートに入る商品の種類が増えても問い合わせ本数が増えない" do
          login_as_employee(@employee)
          more_kinds = -> { stock_new_catalog(@location) }

          assert_queries_unaffected_by(more_kinds, "カートの商品ごとに価格ルールの読み込みが走っている") do
            # 当日在庫のある商品をすべて 1 個ずつ入れた送信。商品を増やせばカートの種類も増える
            quantities = stocked_catalogs(@location).to_h { |catalog| [ catalog.id.to_s, { quantity: "1" } ] }

            post pos_location_sales_form_state_path(@location),
                 params: { ghost_cart: quantities },
                 headers: { "Accept" => "text/vnd.turbo-stream.html" }

            # 本数だけ比べると、リクエストが価格計算の手前で打ち切られても前後で揃って通る。
            # 経路が生きていることまで固定しないとガードが空振りする
            assert_response :success
          end
        end

        test "responds with turbo_stream format" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "turbo-stream", response.body
        end

        test "returns updated product card for item with quantity" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "2" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "cart-item-#{@bento_a.id}", response.body
        end

        test "returns updated price breakdown" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "price-breakdown", response.body
        end

        test "returns updated ghost form" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "3" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "ghost-form", response.body
        end

        test "returns updated coupon cards" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "coupon-card-", response.body
        end

        test "returns updated submit button" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" },
                   customer_type: "staff"
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "sale-submit-button", response.body
        end

        test "employee can access form state" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
        end

        # ============================================================
        # 不正パラメータ耐性
        # ============================================================

        test "構造が壊れたカートを送られても画面は通常どおり再描画される" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => "商品ごとのハッシュではなく文字列",
                   "coupon" => [ "ハッシュではなく配列" ],
                   "customer_type" => "staff"
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :success
          assert_match "price-breakdown", response.body
        end

        test "JSON ボディで数量の位置に数値や真偽値を送られても画面は通常どおり再描画される" do
          login_as_employee(@employee)

          post pos_location_sales_form_state_path(@location),
               params: {
                 ghost_cart: {
                   "coupon" => { "5" => 3, "6" => { "quantity" => true } },
                   "7" => { "quantity" => nil }
                 }
               }.to_json,
               headers: {
                 "Accept" => "text/vnd.turbo-stream.html",
                 "Content-Type" => "application/json"
               }

          assert_response :success
          assert_match "price-breakdown", response.body
        end

        test "returns 404 for inactive location" do
          login_as_employee(@employee)
          inactive_location = locations(:prefectural_office)

          post pos_location_sales_form_state_path(inactive_location),
               params: {
                 ghost_cart: {
                   @bento_a.id.to_s => { quantity: "1" }
                 }
               },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          assert_response :not_found
        end
      end
    end
  end
end
