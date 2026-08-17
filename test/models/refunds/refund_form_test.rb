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

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

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

      assert_predicate form, :has_any_changes?
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

      assert_predicate form, :has_any_changes?
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

      assert_predicate form, :has_any_changes?
      assert_predicate form, :all_items_zero?
    end

    # === バリデーションテスト ===

    test "何も変更しないとバリデーションエラーになる" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

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

      assert_predicate form, :valid?
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

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

      assert_equal 2, form.coupon_quantities[discount.id]
    end

    test "弁当が0個でクーポンの枚数入力が無効化されると、枚数は送られず0枚として扱われる" do
      discount = discounts(:fifty_yen_discount)
      sale = create_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 1 }
      )

      # 弁当が0個だとクーポンは1枚も適用できないため、画面は枚数の入力を無効化する。
      # 無効化された input はブラウザが送信しないので、coupon のキーごと届かない。
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

      assert_empty form.coupon_quantities
      assert_empty form.discount_quantities_for_refunder
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

      assert_predicate form, :has_any_changes?
    end

    test "クーポンを2種類使った販売で、片方のクーポンが送信されなければ、その分が減ったものとして変更ありと判定される" do
      fifty_yen = discounts(:fifty_yen_discount)
      hundred_yen = discounts(:hundred_yen_discount)
      sale = create_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { fifty_yen.id => 1, hundred_yen.id => 1 }
      )

      # 100円クーポンの入力だけが無効化され、coupon の中からその1件だけが欠落した状況。
      # 弁当の数量は元のままなので、減枚を見落とすと変更なしと判定されてしまう
      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "2" }
          },
          "coupon" => {
            fifty_yen.id.to_s => { "quantity" => "1" }
          }
        }
      )

      assert_predicate form, :has_any_changes?
    end

    test "販売後に有効期限が切れたクーポンは、画面に描画されないので変更として数えない" do
      discount = discounts(:fifty_yen_discount)
      sale = create_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 1 }
      )

      # 有効期限が切れると available_discounts から外れ、枚数入力そのものが描画されない。
      # 送信されようがないのだから、届かないことを「0枚に減った」と読んではいけない
      discount.update!(valid_until: 1.day.ago.to_date)

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: {
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "2" }
          }
        }
      )

      assert_not form.has_any_changes?
      assert_equal 0, form.preview_adjustment_amount
    end

    test "元の販売にあった商品が送信されなければ、その商品が減ったものとして変更ありと判定される" do
      sale = create_sale([
        { catalog: @catalog_bento_a, quantity: 1 },
        { catalog: @catalog_salad, quantity: 1 }
      ])

      # corrected の中からサラダの1件だけが欠落した状況
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

      assert_predicate form, :has_any_changes?
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

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

      items = form.corrected_items

      assert_predicate items, :any?
      items.each do |item|
        assert_respond_to item, :catalog_name
        assert_respond_to item, :quantity
        assert_respond_to item, :original_quantity
        assert_respond_to item, :max_quantity
        assert_respond_to item, :changed?
        assert_respond_to item, :sold_out?
      end
    end

    # === 全額返金時のクーポン返却テスト ===

    test "弁当1個+クーポン1枚の販売を全額返金すると、精算プレビューにクーポン1枚返却が含まれる" do
      discount = discounts(:fifty_yen_discount)
      sale = create_sale(
        [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: { discount.id => 1 }
      )

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

      result = form.preview_price_result

      assert_equal 0, result[:final_total]
      assert_empty result[:items_with_prices]

      details = result[:discount_details]
      coupon_detail = details.find { |d| d[:discount_id] == discount.id }

      assert_equal 0, coupon_detail[:quantity]
      assert_equal 1, coupon_detail[:requested_quantity]
    end

    # === tab_items テスト ===

    test "tab_itemsが弁当タブを含む" do
      sale = create_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

      tab_keys = form.tab_items.map { |t| t[:key] }

      assert_includes tab_keys, :bento
    end
  end
end
