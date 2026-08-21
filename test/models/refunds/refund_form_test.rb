require "test_helper"

module Refunds
  class RefundFormTest < ActiveSupport::TestCase
    include GhostFormSubmissionHelper
    include SaleRecordingHelper

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

    def submission_form
      RefundForm
    end

    # === 初期値テスト ===

    test "初期表示時は元の販売の数量で初期化され、変更なしと判定される" do
      sale = record_sale([
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

    # === 数量ハッシュの母集合テスト ===

    test "画面に無い商品が送信されても修正カートには入らない" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])
      # 元の販売にも当日の在庫にも無い商品。数量入力そのものが描画されないので、
      # 届いたとしても画面の操作ではありえない
      unlisted = Catalog.create!(name: "画面に無い弁当", kana: "ガメンニナイベントウ", category: :bento)

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" },
            unlisted.id.to_s => { "quantity" => "5" }
          }
        })
      )

      assert_not_includes form.corrected_quantities.keys, unlisted.id
      assert_not form.has_any_changes?
    end

    test "correctedが1件も届かない送信は、全て0ではなく壊れた送信として弾かれる" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      # 数量が母集合の分だけ埋まっても、送信そのものが壊れていたことは見分けられなければ
      # ならない。ここを通すと corrected_items_for_refunder が空になり、修正後の販売が
      # 作られないまま元の販売が取り消されて全額返金になる
      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({})
      )

      assert_empty form.corrected_items_for_refunder
      assert_not form.valid?
      assert_includes form.errors[:base],
                      "送信された内容を読み取れませんでした。画面を再読み込みしてやり直してください"
    end

    # === corrected パラメータのパーステスト ===

    test "correctedパラメータが正しくパースされる" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 2 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" },
            @catalog_salad.id.to_s => { "quantity" => "1" }
          }
        })
      )

      assert_equal 1, form.corrected_quantities[@catalog_bento_a.id]
      assert_equal 1, form.corrected_quantities[@catalog_salad.id]
    end

    # === corrected_items_for_refunder テスト ===

    test "corrected_items_for_refunderが修正後の数量で商品リストを返す" do
      sale = record_sale([
        { catalog: @catalog_bento_a, quantity: 2 },
        { catalog: @catalog_salad, quantity: 1 }
      ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" },
            @catalog_salad.id.to_s => { "quantity" => "0" },
            @catalog_bento_b.id.to_s => { "quantity" => "1" }
          }
        })
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
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" },
            @catalog_salad.id.to_s => { "quantity" => "1" }
          }
        })
      )

      assert_predicate form, :has_any_changes?
    end

    test "商品数量を減らすとhas_any_changes?がtrueになる" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 2 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" }
          }
        })
      )

      assert_predicate form, :has_any_changes?
    end

    test "全商品を0にするとhas_any_changes?がtrueになる" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "0" }
          }
        })
      )

      assert_predicate form, :has_any_changes?
      assert_empty form.corrected_items_for_refunder
    end

    # === バリデーションテスト ===

    test "何も変更しないとバリデーションエラーになる" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

      assert_not form.valid?
      assert_includes form.errors[:base], "商品数量またはクーポン枚数を変更してください"
    end

    test "数量を変更するとバリデーションが通る" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "0" }
          }
        })
      )

      assert_predicate form, :valid?
    end

    # === クーポン関連テスト ===

    # ロード済みかどうかが初期化の呼び順に左右されないことを、ここで固定する
    # （未ロードで返したときに何が起きるかは available_discounts のコメント）
    test "有効クーポンはロード済みの配列で返る" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

      assert_kind_of Array, form.available_discounts
    end

    test "クーポン数量が初期値として元の販売から設定される" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 2 }
      )

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

      assert_equal 2, form.coupon_quantities[discount.id]
    end

    test "弁当が0個でクーポンの枚数入力が無効化されると、枚数は送られず0枚として扱われる" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 1 }
      )

      # 弁当が0個だとクーポンは1枚も適用できないため、画面は枚数の入力を無効化する。
      # 無効化された input はブラウザが送信しないので、coupon のキーごと届かない。
      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "0" }
          }
        })
      )

      assert_equal 0, form.coupon_quantities[discount.id]
      assert_empty form.discount_quantities_for_refunder
    end

    test "クーポン枚数を変更するとhas_any_changes?がtrueになる" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 2 }
      )

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "2" }
          },
          "coupon" => {
            discount.id.to_s => { "quantity" => "1" }
          }
        })
      )

      assert_predicate form, :has_any_changes?
    end

    test "クーポンを2種類使った販売で、片方のクーポンが送信されなければ、その分が減ったものとして変更ありと判定される" do
      fifty_yen = discounts(:fifty_yen_discount)
      hundred_yen = discounts(:hundred_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { fifty_yen.id => 1, hundred_yen.id => 1 }
      )

      # 100円クーポンの入力だけが無効化され、coupon の中からその1件だけが欠落した状況。
      # 弁当の数量は元のままなので、減枚を見落とすと変更なしと判定されてしまう
      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "2" }
          },
          "coupon" => {
            fifty_yen.id.to_s => { "quantity" => "1" }
          }
        })
      )

      assert_predicate form, :has_any_changes?
    end

    test "販売後に有効期限が切れたクーポンは、画面に描画されないので変更として数えない" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
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
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "2" }
          }
        })
      )

      assert_not form.has_any_changes?
      assert_equal 0, form.preview.adjustment_amount
      # 描画されないクーポンは母集合そのものに入らない
      assert_not_includes form.coupon_quantities.keys, discount.id
    end

    test "元の販売にあった商品が送信されなければ、その商品が減ったものとして変更ありと判定される" do
      sale = record_sale([
        { catalog: @catalog_bento_a, quantity: 1 },
        { catalog: @catalog_salad, quantity: 1 }
      ])

      # corrected の中からサラダの1件だけが欠落した状況
      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" }
          }
        })
      )

      assert_predicate form, :has_any_changes?
      # 届かなかったキーは、元の販売にあった商品も在庫にだけある商品も 0 として読める
      assert_equal 0, form.corrected_quantities[@catalog_salad.id]
      assert_equal 0, form.corrected_quantities[@catalog_bento_b.id]
      # 0 で埋めたキーが集計に混ざらない
      assert_equal 1, form.total_corrected_bento_quantity
    end

    test "変更有無を何度判定しても返却クーポンを出しても、クーポン枚数の取得は1回で済む" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: { discount.id => 1 }
      )

      # 1リクエスト中に画面の各パーツから has_any_changes? が繰り返し呼ばれる。
      # クエリキャッシュを切り、フォーム自身が取得を1回に抑えていることを検証する
      ActiveRecord::Base.uncached do
        assert_queries_match(/FROM ["`]sale_discounts["`]/, count: 1) do
          # 未ロードの Sale から始め、フォーム自身が何本読むかだけを見る。
          # set_sale の preload が効いているかは form_states のコントローラーテストが見る
          form = RefundForm.new(
            sale: Sale.find(sale.id),
            location: @location,
            inventories: @inventories,
            submitted: submission({
              "corrected" => { @catalog_bento_a.id.to_s => { "quantity" => "1" } },
              "coupon" => {}
            })
          )

          3.times { form.has_any_changes? }
          # 返却クーポンも元の販売のクーポンを読む。ここで引き直すと、数量入力を
          # 動かすたびの再描画ごとに問い合わせが増える
          form.preview.returned_discounts
        end
      end
    end

    test "discount_quantities_for_refunderがクーポン数量を正しく返す" do
      discount = discounts(:fifty_yen_discount)
      sale = record_sale(
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discount.id => 2 }
      )

      form = RefundForm.new(
        sale: sale,
        location: @location,
        inventories: @inventories,
        submitted: submission({
          "corrected" => {
            @catalog_bento_a.id.to_s => { "quantity" => "1" }
          },
          "coupon" => {
            discount.id.to_s => { "quantity" => "1" }
          }
        })
      )

      result = form.discount_quantities_for_refunder

      assert_equal 1, result[discount.id]
    end

    # === corrected_items テスト ===

    test "corrected_itemsが全商品（元の販売+在庫）を含む" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])

      form = RefundForm.new(sale: sale, location: @location, inventories: @inventories)

      items = form.corrected_items

      assert_predicate items, :any?
      items.each do |item|
        assert_respond_to item, :catalog_name
        assert_respond_to item, :quantity
        assert_respond_to item, :original_quantity
        assert_respond_to item, :max_quantity
        assert_respond_to item, :changed?
        assert_respond_to item, :unavailable?
        assert_respond_to item, :bento?
        assert_respond_to item, :side_menu?
      end
    end

    # === 陳列カテゴリのガードテスト ===

    # 数量入力の母集合に陳列できない商品が混ざったら、描画にも確定にも進ませない。
    # 通すと、その商品が「0 個に減った」と読まれて黙って返金される（ADR-0005）
    test "陳列カテゴリに載らない商品が母集合に現れたらフォームを組めない" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])
      # enum は validate: true なので、未知の値を代入しても例外にならない（.claude/rules/enum.md）
      dessert = Catalog.new(name: "プリン", kana: "プリン", category: "dessert")
      stocked_dessert = DailyInventory.new(catalog: dessert, stock: 3, reserved_stock: 0)

      error = assert_raises(RefundForm::UndisplayableCategoryError) do
        RefundForm.new(sale: sale, location: @location, inventories: [ stocked_dessert ])
      end

      assert_match(/プリン/, error.message)
    end

    # 実運用で陳列カテゴリを外れた商品が届く経路は元の販売の明細だけである。当日在庫の側は
    # RefundFormBuildable#set_inventories が Catalog.category_order を merge しており、
    # in_order_of の既定 filter: true が WHERE category IN (...) で先に落とす（ADR-0005）
    test "元の販売の明細に陳列カテゴリに載らない商品があってもフォームを組めない" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])
      # enum に無い値は代入では作れない（validate: true が保存を弾く）ので DB 側に直接書く。
      # 3 つ目の区分を足す前の DB だけが先に進んだ状態と同じ形になる
      @catalog_bento_a.update_column(:category, 2)

      error = assert_raises(RefundForm::UndisplayableCategoryError) do
        RefundForm.new(sale: Sale.find(sale.id), location: @location, inventories: @inventories)
      end

      assert_match(/#{Regexp.escape(@catalog_bento_a.name)}/, error.message)
    end

    # 2 つの網が直列にならないことを固定する。3 つ目の区分を足す人は、enum の隣のテスト
    # （catalog_test）に促されて真っ先に DISPLAY_CATEGORIES を更新する。ガードがその定数を
    # 読んでいると、その瞬間にタブを直す前に素通りしてしまう（ADR-0005 の決定 3）。
    # 定数を差し替えるのは、3 つ目の enum 値を足した世界をテスト内で作る唯一の手段のため
    test "陳列カテゴリの定数に値を足しただけではガードは開かない" do
      sale = record_sale([ { catalog: @catalog_bento_a, quantity: 1 } ])
      dessert = Catalog.new(name: "プリン", kana: "プリン", category: "dessert")
      stocked_dessert = DailyInventory.new(catalog: dessert, stock: 3, reserved_stock: 0)

      stub_const(Catalog, :DISPLAY_CATEGORIES, %w[bento side_menu dessert]) do
        assert_raises(RefundForm::UndisplayableCategoryError) do
          RefundForm.new(sale: sale, location: @location, inventories: [ stocked_dessert ])
        end
      end
    end
  end
end
