require "test_helper"

module Sales
  class RecorderTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :daily_inventories

    setup do
      @recorder = Sales::Recorder.new
      @sale_params = {
        location: locations(:city_hall),
        sale_datetime: Time.current,
        customer_type: :staff,
        total_amount: 550,
        final_amount: 500,
        employee: employees(:verified_employee)
      }
      @items_params = [
        {
          catalog: catalogs(:daily_bento_a),
          catalog_price: catalog_prices(:daily_bento_a_regular),
          quantity: 1,
          unit_price: 550,
          sold_at: Time.current
        }
      ]
    end

    # ===== 正常系テスト =====

    test "record creates sale" do
      sale = @recorder.record(@sale_params, @items_params)

      assert sale.persisted?
      assert_equal locations(:city_hall), sale.location
      assert_equal 550, sale.total_amount
    end

    test "record creates sale_items" do
      sale = @recorder.record(@sale_params, @items_params)

      assert_equal 1, sale.sale_items.count
      sale_item = sale.sale_items.first
      assert_equal catalogs(:daily_bento_a), sale_item.catalog
      assert_equal 1, sale_item.quantity
      assert_equal 550, sale_item.unit_price
    end

    test "record creates multiple sale_items" do
      items_params = [
        {
          catalog: catalogs(:daily_bento_a),
          catalog_price: catalog_prices(:daily_bento_a_regular),
          quantity: 2,
          unit_price: 550,
          sold_at: Time.current
        },
        {
          catalog: catalogs(:salad),
          catalog_price: catalog_prices(:salad_regular),
          quantity: 1,
          unit_price: 300,
          sold_at: Time.current
        }
      ]

      sale = @recorder.record(@sale_params, items_params)

      assert_equal 2, sale.sale_items.count
    end

    # ===== 在庫減算テスト =====

    test "record decrements inventory stock" do
      inventory = daily_inventories(:city_hall_bento_a_today)
      initial_stock = inventory.stock

      items_params = [
        {
          catalog: catalogs(:daily_bento_a),
          catalog_price: catalog_prices(:daily_bento_a_regular),
          quantity: 2,
          unit_price: 550,
          sold_at: Time.current
        }
      ]

      @recorder.record(@sale_params, items_params)

      inventory.reload
      assert_equal initial_stock - 2, inventory.stock
    end

    test "record decrements inventory for multiple items" do
      inventory_a = daily_inventories(:city_hall_bento_a_today)
      inventory_salad = daily_inventories(:city_hall_salad_today)
      initial_stock_a = inventory_a.stock
      initial_stock_salad = inventory_salad.stock

      items_params = [
        {
          catalog: catalogs(:daily_bento_a),
          catalog_price: catalog_prices(:daily_bento_a_regular),
          quantity: 3,
          unit_price: 550,
          sold_at: Time.current
        },
        {
          catalog: catalogs(:salad),
          catalog_price: catalog_prices(:salad_regular),
          quantity: 2,
          unit_price: 300,
          sold_at: Time.current
        }
      ]

      @recorder.record(@sale_params, items_params)

      inventory_a.reload
      inventory_salad.reload
      assert_equal initial_stock_a - 3, inventory_a.stock
      assert_equal initial_stock_salad - 2, inventory_salad.stock
    end

    # ===== エラーケーステスト =====

    test "raises InsufficientStockError when stock is insufficient" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      items_params = [
        {
          catalog: catalogs(:daily_bento_a),
          catalog_price: catalog_prices(:daily_bento_a_regular),
          quantity: inventory.stock + 100,
          unit_price: 550,
          sold_at: Time.current
        }
      ]

      assert_raises DailyInventory::InsufficientStockError do
        @recorder.record(@sale_params, items_params)
      end
    end

    test "raises RecordNotFound when inventory does not exist" do
      items_params = [
        {
          catalog: catalogs(:miso_soup),
          catalog_price: catalog_prices(:daily_bento_a_regular),
          quantity: 1,
          unit_price: 100,
          sold_at: Time.current
        }
      ]

      assert_raises ActiveRecord::RecordNotFound do
        @recorder.record(@sale_params, items_params)
      end
    end

    # ===== トランザクションテスト =====

    test "rolls back all changes when inventory decrement fails" do
      initial_sale_count = Sale.count
      initial_sale_item_count = SaleItem.count
      inventory = daily_inventories(:city_hall_bento_a_today)
      initial_stock = inventory.stock

      items_params = [
        {
          catalog: catalogs(:daily_bento_a),
          catalog_price: catalog_prices(:daily_bento_a_regular),
          quantity: 1,
          unit_price: 550,
          sold_at: Time.current
        },
        {
          catalog: catalogs(:miso_soup),  # 在庫なし
          catalog_price: catalog_prices(:daily_bento_a_regular),
          quantity: 1,
          unit_price: 100,
          sold_at: Time.current
        }
      ]

      assert_raises ActiveRecord::RecordNotFound do
        @recorder.record(@sale_params, items_params)
      end

      # ロールバックされていることを確認
      assert_equal initial_sale_count, Sale.count
      assert_equal initial_sale_item_count, SaleItem.count
      inventory.reload
      assert_equal initial_stock, inventory.stock
    end
  end
end
