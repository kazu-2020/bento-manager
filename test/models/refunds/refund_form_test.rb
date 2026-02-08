require "test_helper"

module Refunds
  class RefundFormTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules,
             :daily_inventories, :coupons, :discounts

    setup do
      @location = locations(:city_hall)
      @employee = employees(:verified_employee)
      @catalog_bento_a = catalogs(:daily_bento_a)
      @catalog_bento_b = catalogs(:daily_bento_b)
      @catalog_salad = catalogs(:salad)
      @inventories = @location
                        .today_inventories
                        .eager_load(catalog: :prices)
                        .merge(Catalog.category_order)
    end

    def create_sale(items, discount_quantities: {})
      recorder = Sales::Recorder.new
      recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        items,
        discount_quantities: discount_quantities
      )
    end

    # === 初期値テスト ===

    test "初期表示時は元の販売の数量で初期化され、変更なしと判定される" do
      sale = create_sale([
        { catalog: @catalog_bento_a, quantity: 2 },
        { catalog: @catalog_salad, quantity: 1 }
      ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {}
      )

      # 元の販売の数量で初期化
      assert_equal 2, form.corrected_quantities[@catalog_bento_a.id]
      assert_equal 1, form.corrected_quantities[@catalog_salad.id]
      # 在庫にある未購入商品は0
      assert_equal 0, form.corrected_quantities[@catalog_bento_b.id]
      # 変更なし
      assert_not form.has_any_changes?
    end

    # === corrected パラメータのパーステスト ===

    test "correctedパラメータが正しくパースされる" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 2 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" },
            @catalog_salad.id.to_s => { "quantity" => "1" }
          }
        }
      )

      assert_equal 1, form.corrected_quantities[@catalog_bento_a.id]
      assert_equal 1, form.corrected_quantities[@catalog_salad.id]
    end

    # === corrected_items_for_refunder テスト ===

    test "corrected_items_for_refunderが修正後の数量で商品リストを返す" do
      sale = create_sale([
        { catalog: @catalog_bento_a, quantity: 2 },
        { catalog: @catalog_salad, quantity: 1 }
      ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" },
            @catalog_salad.id.to_s => { "quantity" => "0" },
            @catalog_bento_b.id.to_s => { "quantity" => "1" }
          }
        }
      )

      corrected = form.corrected_items_for_refunder

      # 弁当A: 修正後1個
      bento_a_item = corrected.find { |item| item[:catalog].id == @catalog_bento_a.id }
      assert_equal 1, bento_a_item[:quantity]

      # サラダ: 0個（含まれない）
      salad_item = corrected.find { |item| item[:catalog].id == @catalog_salad.id }
      assert_nil salad_item

      # 弁当B: 新規追加1個
      bento_b_item = corrected.find { |item| item[:catalog].id == @catalog_bento_b.id }
      assert_equal 1, bento_b_item[:quantity]
    end

    # === has_any_changes? テスト ===

    test "商品数量を増やすとhas_any_changes?がtrueになる" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" },
            @catalog_salad.id.to_s => { "quantity" => "1" }
          }
        }
      )

      assert form.has_any_changes?
    end

    test "商品数量を減らすとhas_any_changes?がtrueになる" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 2 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" }
          }
        }
      )

      assert form.has_any_changes?
    end

    test "全商品を0にするとhas_any_changes?がtrueになる" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "0" }
          }
        }
      )

      assert form.has_any_changes?
      assert form.all_items_zero?
    end

    # === バリデーションテスト ===

    test "何も変更しないとバリデーションエラーになる" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {}
      )

      assert_not form.valid?
      assert_includes form.errors[:base], "商品数量またはクーポン枚数を変更してください"
    end

    test "数量を変更するとバリデーションが通る" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "0" }
          }
        }
      )

      assert form.valid?
    end

    # === preview_adjustment_amount テスト ===

    test "商品を追加した場合のpreview_adjustment_amountが正しく計算される" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" },
            @catalog_salad.id.to_s => { "quantity" => "1" }
          }
        }
      )

      # 弁当A(550) + サラダ(セット価格150) = 700円
      # 差額: 550 - 700 = -150（追加徴収）
      assert_equal(-150, form.preview_adjustment_amount)
    end

    # === クーポン関連テスト ===

    test "クーポン数量が初期値として元の販売から設定される" do
      discount = discounts(:fifty_yen_discount)
      sale = create_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 2 }
      )

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {}
      )

      assert_equal 2, form.coupon_quantities[discount.id]
    end

    test "クーポン枚数を変更するとhas_any_changes?がtrueになる" do
      discount = discounts(:fifty_yen_discount)
      sale = create_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 2 }
      )

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "2" }
          },
          "coupon" => {
            discount.id.to_s => { "quantity" => "1" }
          }
        }
      )

      assert form.has_any_changes?
    end

    test "discount_quantities_for_refunderがクーポン数量を正しく返す" do
      discount = discounts(:fifty_yen_discount)
      sale = create_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 2 }
      )

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" }
          },
          "coupon" => {
            discount.id.to_s => { "quantity" => "1" }
          }
        }
      )

      result = form.discount_quantities_for_refunder
      assert_equal 1, result[discount.id]
    end

    # === corrected_items テスト ===

    test "corrected_itemsが全商品（元の販売+在庫）を含む" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {}
      )

      items = form.corrected_items
      assert items.any?
      items.each do |item|
        assert_respond_to item, :catalog_name
        assert_respond_to item, :quantity
        assert_respond_to item, :original_quantity
        assert_respond_to item, :max_quantity
        assert_respond_to item, :changed?
        assert_respond_to item, :sold_out?
      end
    end

    # === tab_items テスト ===

    test "tab_itemsが弁当タブを含む" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {}
      )

      tab_keys = form.tab_items.map { |t| t[:key] }
      assert_includes tab_keys, :bento
    end
  end
end
