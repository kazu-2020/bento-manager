require "test_helper"

module Sales
  class RecorderTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules, :daily_inventories

    setup do
      @recorder = Sales::Recorder.new
      @sale_params = {
        location: locations(:city_hall),
        customer_type: :staff,
        employee: employees(:verified_employee)
      }
      @items_params = [
        {
          catalog: catalogs(:daily_bento_a),
          quantity: 1
        }
      ]
    end

    # ===== 正常系テスト =====

    test "record creates sale with calculated prices" do
      sale = @recorder.record(@sale_params, @items_params)

      assert sale.persisted?
      assert_equal locations(:city_hall), sale.location
      # PriceCalculator が計算した価格が設定される
      assert_equal 550, sale.total_amount
      assert_equal 550, sale.final_amount
      assert_not_nil sale.sale_datetime
    end

    test "record creates items with calculated unit_price" do
      sale = @recorder.record(@sale_params, @items_params)

      assert_equal 1, sale.items.count
      sale_item = sale.items.first
      assert_equal catalogs(:daily_bento_a), sale_item.catalog
      assert_equal 1, sale_item.quantity
      # PriceCalculator が計算した単価が設定される
      assert_equal 550, sale_item.unit_price
      assert_equal catalog_prices(:daily_bento_a_regular).id, sale_item.catalog_price_id
      assert_not_nil sale_item.sold_at
    end

    test "record creates multiple sale_items" do
      items_params = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 },
        { catalog: catalogs(:salad), quantity: 1 }
      ]

      sale = @recorder.record(@sale_params, items_params)

      # 弁当2個とサラダ1個（セット価格適用）
      assert_equal 2, sale.items.count
    end

    test "record applies bundle price when bento and salad are purchased together" do
      items_params = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 1 }
      ]

      sale = @recorder.record(@sale_params, items_params)

      # 弁当550円 + サラダ150円（セット価格）= 700円
      assert_equal 700, sale.total_amount
      assert_equal 700, sale.final_amount

      salad_item = sale.items.find_by(catalog: catalogs(:salad))
      assert_equal 150, salad_item.unit_price
      assert_equal catalog_prices(:salad_bundle).id, salad_item.catalog_price_id
    end

    # ===== 在庫減算テスト =====

    test "record decrements inventory stock" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      items_params = [
        { catalog: catalogs(:daily_bento_a), quantity: 2 }
      ]

      assert_changes -> { inventory.reload.stock }, from: inventory.stock, to: inventory.stock - 2 do
        @recorder.record(@sale_params, items_params)
      end
    end

    test "record decrements inventory for multiple items" do
      inventory_a = daily_inventories(:city_hall_bento_a_today)
      inventory_salad = daily_inventories(:city_hall_salad_today)

      items_params = [
        { catalog: catalogs(:daily_bento_a), quantity: 3 },
        { catalog: catalogs(:salad), quantity: 2 }
      ]

      assert_difference -> { inventory_a.reload.stock }, -3 do
        assert_difference -> { inventory_salad.reload.stock }, -2 do
          @recorder.record(@sale_params, items_params)
        end
      end
    end

    # ===== エラーケーステスト =====

    test "raises InsufficientStockError when stock is insufficient" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      items_params = [
        { catalog: catalogs(:daily_bento_a), quantity: inventory.stock + 100 }
      ]

      assert_raises DailyInventory::InsufficientStockError do
        @recorder.record(@sale_params, items_params)
      end
    end

    test "raises RecordNotFound when inventory does not exist" do
      # discontinued_bento には価格があるが在庫がない
      # まず価格を追加
      CatalogPrice.create!(
        catalog: catalogs(:discontinued_bento),
        kind: :regular,
        price: 400,
        effective_from: 1.month.ago
      )

      items_params = [
        { catalog: catalogs(:discontinued_bento), quantity: 1 }
      ]

      assert_raises ActiveRecord::RecordNotFound do
        @recorder.record(@sale_params, items_params)
      end
    end

    # ===== トランザクションテスト =====

    test "rolls back all changes when inventory decrement fails" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      # discontinued_bento には価格があるが在庫がない
      CatalogPrice.create!(
        catalog: catalogs(:discontinued_bento),
        kind: :regular,
        price: 400,
        effective_from: 1.month.ago
      )

      items_params = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:discontinued_bento), quantity: 1 }  # 在庫なし
      ]

      assert_no_difference [ "Sale.count", "SaleItem.count" ] do
        assert_no_changes -> { inventory.reload.stock } do
          assert_raises ActiveRecord::RecordNotFound do
            @recorder.record(@sale_params, items_params)
          end
        end
      end
    end

    # ===== 価格存在検証テスト（Task 41.5）=====

    test "raises MissingPriceError when catalog has no price" do
      # miso_soup には価格が設定されていない
      items_params = [
        { catalog: catalogs(:miso_soup), quantity: 1 }
      ]

      assert_raises Errors::MissingPriceError do
        @recorder.record(@sale_params, items_params)
      end
    end

    test "does not create sale or decrement inventory when price validation fails" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      items_params = [
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:miso_soup), quantity: 1 }  # 価格なし
      ]

      assert_no_difference [ "Sale.count", "SaleItem.count" ] do
        assert_no_changes -> { inventory.reload.stock } do
          assert_raises Errors::MissingPriceError do
            @recorder.record(@sale_params, items_params)
          end
        end
      end
    end

    test "logs error when price validation fails" do
      items_params = [
        { catalog: catalogs(:miso_soup), quantity: 1 }
      ]

      # MissingPriceError が発生し、内部でログ出力される
      # (ログ出力の検証は統合テストで実施)
      assert_raises Errors::MissingPriceError do
        @recorder.record(@sale_params, items_params)
      end
    end
  end
end
