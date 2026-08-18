require "test_helper"

module Sales
  class RefunderTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules,
             :daily_inventories, :coupons, :discounts, :sales, :sale_items

    setup do
      @location = locations(:city_hall)
      @employee = employees(:verified_employee)
      @catalog_bento_a = catalogs(:daily_bento_a)
      @catalog_bento_b = catalogs(:daily_bento_b)
      @catalog_salad = catalogs(:salad)
      @inventory_bento_a = daily_inventories(:city_hall_bento_a_today)
      @inventory_bento_b = daily_inventories(:city_hall_bento_b_today)
      @inventory_salad = daily_inventories(:city_hall_salad_today)
    end

    test "弁当1個(550円)を全額返金すると550円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      original_stock = @inventory_bento_a.reload.stock

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [],
        employee: @employee
      )

      assert_equal 550, result[:refund_amount]
      assert_nil result[:corrected_sale]

      sale.reload

      assert_predicate sale, :voided?

      @inventory_bento_a.reload

      assert_equal original_stock + 1, @inventory_bento_a.stock

      refund = result[:refund]

      assert_equal sale.id, refund.original_sale_id
      assert_nil refund.corrected_sale_id
      assert_equal 550, refund.amount
    end

    test "弁当2個(1100円)のうち1個を返品すると550円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 2 } ]
      )

      original_stock = @inventory_bento_a.reload.stock

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        employee: @employee
      )

      sale.reload

      assert_predicate sale, :voided?

      corrected_sale = result[:corrected_sale]

      assert_predicate corrected_sale, :present?
      assert_predicate corrected_sale, :completed?
      assert_equal sale.id, corrected_sale.corrected_from_sale_id
      assert_equal 550, corrected_sale.final_amount

      assert_equal 550, result[:refund_amount]

      @inventory_bento_a.reload

      assert_equal original_stock + 1, @inventory_bento_a.stock
    end

    test "弁当+サラダ(700円)からサラダを返品すると150円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [
          { catalog: @catalog_bento_a, quantity: 1 },
          { catalog: @catalog_salad, quantity: 1 }
        ]
      )

      assert_equal 700, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]

      assert_equal 550, corrected_sale.final_amount

      assert_equal 150, result[:refund_amount]
    end

    test "弁当+サラダ(700円)から弁当を返品するとサラダが単品価格に再評価されて450円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [
          { catalog: @catalog_bento_a, quantity: 1 },
          { catalog: @catalog_salad, quantity: 1 }
        ]
      )

      assert_equal 700, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_salad, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]

      assert_equal 250, corrected_sale.final_amount

      assert_equal 450, result[:refund_amount]
    end

    test "弁当1個(550円)+50円クーポンを全額返金すると500円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: { discounts(:fifty_yen_discount).id => 1 }
      )

      assert_equal 500, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [],
        employee: @employee
      )

      assert_equal 500, result[:refund_amount]
      assert_nil result[:corrected_sale]
    end

    test "弁当3個(1500円)+50円クーポン2枚(1400円)から弁当2個を返品すると950円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_b, quantity: 3 } ],
        discount_quantities: { discounts(:fifty_yen_discount).id => 2 }
      )

      assert_equal 1400, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_b, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]
      # 弁当1個(500円) - クーポン1枚適用(50円) = 450円
      # ※弁当1個につきクーポン1枚までなので、2枚中1枚のみ適用
      assert_equal 450, corrected_sale.final_amount

      # 返金額: 1400円 - 450円 = 950円
      assert_equal 950, result[:refund_amount]
    end

    test "弁当2個+50円クーポン2枚から弁当1個を返品すると、クーポン1枚のみ適用され500円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 2 } ],
        discount_quantities: { discounts(:fifty_yen_discount).id => 2 }
      )

      # 弁当2個(1100円) - クーポン2枚(100円) = 1000円
      assert_equal 1000, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]
      # 弁当1個(550円) - クーポン1枚適用(50円) = 500円
      # ※弁当1個につきクーポン1枚までなので、2枚中1枚のみ適用
      assert_equal 500, corrected_sale.final_amount

      # 返金額: 1000円 - 500円 = 500円
      # ※クーポン1枚は返却されるが、金銭的な返金は500円
      assert_equal 500, result[:refund_amount]
    end

    test "既にvoidedの販売には返金処理できない" do
      voided_sale = sales(:voided_sale)

      refunder = Sales::Refunder.new
      assert_raises(Sale::AlreadyVoidedError) do
        refunder.process(
          sale: voided_sale,
          corrected_items: [],
          employee: @employee
        )
      end
    end

    test "同じ販売に差額精算が二重に走っても在庫の復元と差額の記録は1回だけになる" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )
      # 先に差額精算へ入ったリクエストの裏で、同じ販売を読み込んだ別リクエスト
      stale_sale = Sale.find(sale.id)

      refunder = Sales::Refunder.new
      refunder.process(sale: sale, corrected_items: [], employee: @employee)

      assert_no_difference [ "Refund.count", "@inventory_bento_a.reload.stock" ] do
        assert_raises Sale::AlreadyVoidedError do
          refunder.process(sale: stale_sale, corrected_items: [], employee: @employee)
        end
      end
    end

    # === 差額精算テスト ===

    test "弁当A(550円)を弁当B(500円)に交換すると差額50円が返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      assert_equal 550, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_b, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]

      assert_equal 500, corrected_sale.final_amount

      # 差額: 550 - 500 = 50（返金）
      assert_equal 50, result[:refund_amount]
      assert_predicate result[:refund_amount], :positive?
    end

    test "弁当A(550円)をサラダ(250円)に交換すると300円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_salad, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]

      assert_equal 250, corrected_sale.final_amount

      assert_equal 300, result[:refund_amount]
      assert_predicate result[:refund_amount], :positive?
    end

    test "弁当A(550円)にサラダを追加すると-150円（追加徴収）になる" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      assert_equal 550, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [
          { catalog: @catalog_bento_a, quantity: 1 },
          { catalog: @catalog_salad, quantity: 1 }
        ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]
      # 弁当A(550) + サラダ(セット価格150) = 700円
      assert_equal 700, corrected_sale.final_amount

      # 差額: 550 - 700 = -150（追加徴収）
      assert_equal(-150, result[:refund_amount])
      assert_predicate result[:refund_amount], :negative?

      # Refund レコードにマイナス値が保存される
      refund = result[:refund]

      assert_equal(-150, refund.amount)
    end

    test "サラダ(250円)を弁当A(550円)に交換すると-300円（追加徴収）になる" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_salad, quantity: 1 } ]
      )

      assert_equal 250, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]

      assert_equal 550, corrected_sale.final_amount

      # 差額: 250 - 550 = -300（追加徴収）
      assert_equal(-300, result[:refund_amount])
      assert_predicate result[:refund_amount], :negative?
    end

    test "弁当A+クーポン(500円)を弁当B+クーポン(450円)に交換すると50円返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: { discounts(:fifty_yen_discount).id => 1 }
      )

      assert_equal 500, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_b, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]
      # 弁当B(500円) - クーポン1枚(50円) = 450円
      assert_equal 450, corrected_sale.final_amount

      # 差額: 500 - 450 = 50（返金）
      assert_equal 50, result[:refund_amount]
    end

    # === 割引を明示指定する経路（コントローラが常に通す経路）===
    #
    # discount_quantities を省略すると元の販売の割引が引き継がれる。
    # コントローラは常に修正後のクーポン枚数を明示的に渡すため、
    # 引き継ぎではなく指定値が使われることを検証する。

    test "クーポンを外して同じ商品を買い直すとクーポン分が追加徴収される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: { discounts(:fifty_yen_discount).id => 1 }
      )

      assert_equal 500, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        employee: @employee,
        discount_quantities: {}
      )

      corrected_sale = result[:corrected_sale]
      # クーポンが引き継がれず弁当A(550円)のみ
      assert_equal 550, corrected_sale.final_amount
      assert_empty corrected_sale.sale_discounts

      # 差額: 500 - 550 = -50（追加徴収）
      assert_equal(-50, result[:refund_amount])
    end

    test "クーポンを新たに適用して買い直すとクーポン分が返金される" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      assert_equal 550, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        employee: @employee,
        discount_quantities: { discounts(:fifty_yen_discount).id => 1 }
      )

      corrected_sale = result[:corrected_sale]
      # 元の販売にはなかったクーポンが適用される
      assert_equal 500, corrected_sale.final_amount
      assert_equal 1, corrected_sale.sale_discounts.count

      # 差額: 550 - 500 = 50（返金）
      assert_equal 50, result[:refund_amount]
    end

    test "弁当A+クーポン(500円)を弁当B(500円)に交換すると差額なしになる" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ],
        discount_quantities: { discounts(:fifty_yen_discount).id => 1 }
      )

      assert_equal 500, sale.final_amount

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        corrected_items: [ { catalog: @catalog_bento_b, quantity: 1 } ],
        employee: @employee,
        discount_quantities: {}
      )

      corrected_sale = result[:corrected_sale]

      assert_equal 500, corrected_sale.final_amount

      # 差額: 500 - 500 = 0（等価交換）
      assert_predicate result[:refund_amount], :zero?
      assert_equal 0, result[:refund].amount
    end

    test "取り消し前に読まれた販売を渡されても、返金も在庫の復元も一度きりで済む" do
      sale = Sales::Recorder.new.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )
      # 画面を2つ開いて続けて確定を押すと、後の送信は取り消し前の行を読んだまま届く
      stale_sale = Sale.find(sale.id)

      Sales::Refunder.new.process(sale: sale, corrected_items: [], employee: @employee)

      # メモリ上の status だけで判定すると素通りし、Refund が2件でき在庫も二度戻る
      assert_no_difference "Refund.count" do
        assert_no_changes -> { @inventory_bento_a.reload.stock } do
          assert_raises Sale::AlreadyVoidedError do
            Sales::Refunder.new.process(sale: stale_sale, corrected_items: [], employee: @employee)
          end
        end
      end
    end

    test "前日の販売は差額精算できず、どちらの日の在庫も元の販売も変化しない" do
      yesterday_inventory = daily_inventories(:city_hall_bento_a_yesterday)
      sale = travel_to(1.day.ago) do
        Sales::Recorder.new.record(
          { location: @location, customer_type: :staff, employee: @employee },
          [ { catalog: @catalog_bento_a, quantity: 1 } ]
        )
      end

      refunder = Sales::Refunder.new

      # 元の販売日の在庫は戻さず、当日の在庫も減らさない
      assert_no_difference [ "Refund.count", "Sale.count" ] do
        assert_no_changes -> { [ yesterday_inventory.reload.stock, @inventory_bento_a.reload.stock ] } do
          assert_raises Sale::NotTodaysSaleError do
            refunder.process(sale: sale, corrected_items: [], employee: @employee)
          end
        end
      end

      assert_not_predicate sale.reload, :voided?
    end
  end
end
