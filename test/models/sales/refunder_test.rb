require "test_helper"

module Sales
  class RefunderTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules,
             :daily_inventories, :coupons, :discounts, :sales, :sale_items

    setup do
      @location = locations(:city_hall)
      @employee = employees(:verified_employee)
      @catalog_bento_a = catalogs(:daily_bento_a)
      @catalog_salad = catalogs(:salad)
      @inventory_bento_a = daily_inventories(:city_hall_bento_a_today)
      @inventory_salad = daily_inventories(:city_hall_salad_today)
    end

    # ===== 11.4: 返品・返金処理ロジック =====

    # --- 全額返金テスト ---

    test "全額返金: 全商品を返品する場合、元の Sale を void にして全額返金" do
      # Arrange: 販売を作成
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      original_stock = @inventory_bento_a.reload.stock

      # Act: 全額返金
      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        remaining_items: [],  # 全商品返品
        reason: "全額返金テスト",
        employee: @employee
      )

      # Assert
      assert_equal sale.final_amount, result[:refund_amount]
      assert_nil result[:corrected_sale]

      # 元の Sale が voided になっている
      sale.reload
      assert sale.voided?
      assert_equal "全額返金テスト", sale.void_reason

      # 在庫が復元されている
      @inventory_bento_a.reload
      assert_equal original_stock + 1, @inventory_bento_a.stock

      # Refund レコードが作成されている
      refund = result[:refund]
      assert_equal sale.id, refund.original_sale_id
      assert_nil refund.corrected_sale_id
      assert_equal sale.final_amount, refund.amount
      assert_equal "全額返金テスト", refund.reason
    end

    # --- 部分返金テスト ---

    test "部分返金: 一部商品を返品する場合、void + 再販売 + 差額返金" do
      # Arrange: 弁当2個の販売を作成（合計 1100円）
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 2 } ]
      )

      original_stock = @inventory_bento_a.reload.stock
      original_final_amount = sale.final_amount

      # Act: 1個返品（1個残す）
      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        remaining_items: [ { catalog: @catalog_bento_a, quantity: 1 } ],
        reason: "1個返品",
        employee: @employee
      )

      # Assert: 元の Sale が voided になっている
      sale.reload
      assert sale.voided?

      # 新しい Sale が作成されている
      corrected_sale = result[:corrected_sale]
      assert corrected_sale.present?
      assert corrected_sale.completed?
      assert_equal sale.id, corrected_sale.corrected_from_sale_id

      # 新しい Sale の金額は1個分
      assert_equal 550, corrected_sale.final_amount

      # 返金額は差額
      expected_refund = original_final_amount - corrected_sale.final_amount
      assert_equal expected_refund, result[:refund_amount]

      # 在庫は1個分だけ復元（2個戻して1個減らす = 1個増加）
      @inventory_bento_a.reload
      assert_equal original_stock + 1, @inventory_bento_a.stock

      # Refund レコードが作成されている
      refund = result[:refund]
      assert_equal sale.id, refund.original_sale_id
      assert_equal corrected_sale.id, refund.corrected_sale_id
      assert_equal expected_refund, refund.amount
    end

    # --- 価格ルール再評価テスト ---

    test "部分返金: 弁当返品でサラダがセット価格から単品価格に再評価される" do
      # Arrange: 弁当1個 + サラダ1個（セット価格）
      # 弁当550円 + サラダ150円（セット価格）= 700円
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [
          { catalog: @catalog_bento_a, quantity: 1 },
          { catalog: @catalog_salad, quantity: 1 }
        ]
      )

      original_final_amount = sale.final_amount  # 700円

      # Act: 弁当を返品（サラダのみ残す）
      refunder = Sales::Refunder.new
      result = refunder.process(
        sale: sale,
        remaining_items: [ { catalog: @catalog_salad, quantity: 1 } ],
        reason: "弁当を返品",
        employee: @employee
      )

      # Assert: 新しい Sale のサラダは単品価格（250円）になる
      corrected_sale = result[:corrected_sale]
      assert_equal 250, corrected_sale.final_amount

      # 返金額: 700円 - 250円 = 450円
      assert_equal 450, result[:refund_amount]
    end

    # --- エラーケーステスト ---

    test "既に voided の Sale には返金処理できない" do
      # Arrange: voided 状態の Sale
      voided_sale = sales(:voided_sale)

      # Act & Assert
      refunder = Sales::Refunder.new
      assert_raises(Sale::AlreadyVoidedError) do
        refunder.process(
          sale: voided_sale,
          remaining_items: [],
          reason: "テスト",
          employee: @employee
        )
      end
    end

    test "返金処理がロールバックされた場合、在庫は変更されない" do
      # Arrange: 販売を作成
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      # Act: 無効なパラメータでエラーを発生させる（空の reason は Sale#void! のバリデーションでエラー）
      refunder = Sales::Refunder.new

      assert_no_changes -> { @inventory_bento_a.reload.stock } do
        assert_raises(ActiveRecord::RecordInvalid) do
          refunder.process(
            sale: sale,
            remaining_items: [],
            reason: "",  # 空の理由で Sale#void! がバリデーションエラー
            employee: @employee
          )
        end
      end

      # Sale は voided になっていない
      sale.reload
      assert sale.completed?
    end

    # --- トランザクション整合性テスト ---

    test "返金処理はトランザクション内で原子的に実行される" do
      # Arrange: 販売を作成
      recorder = Sales::Recorder.new
      sale = recorder.record(
        { location: @location, customer_type: :staff, employee: @employee },
        [ { catalog: @catalog_bento_a, quantity: 1 } ]
      )

      # Act & Assert: Sale, Refund の作成がトランザクション内で行われる
      refunder = Sales::Refunder.new

      assert_difference [ "Refund.count" ], 1 do
        assert_no_difference [ "SaleItem.count" ] do  # 全額返金なので新規 SaleItem は作成されない
          refunder.process(
            sale: sale,
            remaining_items: [],
            reason: "全額返金",
            employee: @employee
          )
        end
      end
    end
  end
end
