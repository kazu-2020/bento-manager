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

    # ===== 基本的な返金（クーポンなし）=====

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
        remaining_items: [],
        employee: @employee
      )

      assert_equal 550, result[:refund_amount]
      assert_nil result[:corrected_sale]

      sale.reload
      assert sale.voided?

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
        remaining_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        employee: @employee
      )

      sale.reload
      assert sale.voided?

      corrected_sale = result[:corrected_sale]
      assert corrected_sale.present?
      assert corrected_sale.completed?
      assert_equal sale.id, corrected_sale.corrected_from_sale_id
      assert_equal 550, corrected_sale.final_amount

      assert_equal 550, result[:refund_amount]

      @inventory_bento_a.reload
      assert_equal original_stock + 1, @inventory_bento_a.stock
    end

    # ===== セット割引の返金 =====

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
        remaining_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
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
        remaining_items: [ { catalog: @catalog_salad, quantity: 1 } ],
        employee: @employee
      )

      corrected_sale = result[:corrected_sale]
      assert_equal 250, corrected_sale.final_amount

      assert_equal 450, result[:refund_amount]
    end

    # ===== クーポン割引の返金 =====

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
        remaining_items: [],
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
        remaining_items: [ { catalog: @catalog_bento_b, quantity: 1 } ],
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
        remaining_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
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

    # ===== エラーケース =====

    test "既にvoidedの販売には返金処理できない" do
      voided_sale = sales(:voided_sale)

      refunder = Sales::Refunder.new
      assert_raises(Sale::AlreadyVoidedError) do
        refunder.process(
          sale: voided_sale,
          remaining_items: [],
          employee: @employee
        )
      end
    end

    test "返金処理は正常に実行できる" do
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        remaining_items: [],
        employee: @employee
      )

      sale.reload
      assert sale.voided?
      assert_equal 550, result[:refund_amount]
    end
  end
end
