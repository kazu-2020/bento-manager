require "test_helper"

module Sales
  class RecorderTest < ActiveSupport::TestCase
    fixtures :locations, :employees, :catalogs, :catalog_prices, :catalog_pricing_rules, :daily_inventories, :discounts, :coupons

    # ===== 基本的な販売記録 =====

    test "弁当1個(550円)を販売記録すると合計550円のSaleが作成される" do
      sale = record_sale([
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ])

      assert sale.persisted?
      assert_equal locations(:city_hall), sale.location
      assert_equal 550, sale.total_amount
      assert_equal 550, sale.final_amount
      assert_not_nil sale.sale_datetime
    end

    test "弁当1個(550円)の販売記録でSaleItemに単価550円と価格IDが設定される" do
      sale = record_sale([
        { catalog: catalogs(:daily_bento_a), quantity: 1 }
      ])

      assert_equal 1, sale.items.count
      sale_item = sale.items.first
      assert_equal catalogs(:daily_bento_a), sale_item.catalog
      assert_equal 1, sale_item.quantity
      assert_equal 550, sale_item.unit_price
      assert_equal catalog_prices(:daily_bento_a_regular).id, sale_item.catalog_price_id
      assert_not_nil sale_item.sold_at
    end

    test "弁当2個とサラダ1個を販売記録すると2種類のSaleItemが作成される" do
      sale = record_sale([
        { catalog: catalogs(:daily_bento_a), quantity: 2 },
        { catalog: catalogs(:salad), quantity: 1 }
      ])

      assert_equal 2, sale.items.count
    end

    # ===== セット割引の販売記録 =====

    test "弁当(550円)とサラダのセット購入を記録すると合計700円でサラダはセット価格150円になる" do
      sale = record_sale([
        { catalog: catalogs(:daily_bento_a), quantity: 1 },
        { catalog: catalogs(:salad), quantity: 1 }
      ])

      assert_equal 700, sale.total_amount
      assert_equal 700, sale.final_amount

      salad_item = sale.items.find_by(catalog: catalogs(:salad))
      assert_equal 150, salad_item.unit_price
      assert_equal catalog_prices(:salad_bundle).id, salad_item.catalog_price_id
    end

    # ===== クーポン適用の販売記録 =====

    test "弁当1個(550円)に50円クーポン1枚を適用すると割引50円のSaleDiscountが作成される" do
      sale = record_sale(
        [ { catalog: catalogs(:daily_bento_a), quantity: 1 } ],
        discount_quantities: { discounts(:fifty_yen_discount).id => 1 }
      )

      assert_equal 550, sale.total_amount
      assert_equal 500, sale.final_amount
      assert_equal 1, sale.sale_discounts.count

      sd = sale.sale_discounts.first
      assert_equal discounts(:fifty_yen_discount).id, sd.discount_id
      assert_equal 50, sd.discount_amount
      assert_equal 1, sd.quantity
    end

    test "弁当3個(550円)に50円クーポン3枚を適用するとdiscount_amount=150でquantity=3のSaleDiscountが作成される" do
      sale = record_sale(
        [ { catalog: catalogs(:daily_bento_a), quantity: 3 } ],
        discount_quantities: { discounts(:fifty_yen_discount).id => 3 }
      )

      assert_equal 1650, sale.total_amount
      assert_equal 1500, sale.final_amount

      sd = sale.sale_discounts.first
      assert_equal 150, sd.discount_amount
      assert_equal 3, sd.quantity
    end

    test "弁当2個に50円クーポン2枚と100円クーポン1枚を指定しても弁当数上限で合計2枚のみ適用される" do
      sale = record_sale(
        [ { catalog: catalogs(:daily_bento_a), quantity: 2 } ],
        discount_quantities: {
          discounts(:fifty_yen_discount).id => 2,
          discounts(:hundred_yen_discount).id => 1
        }
      )

      assert_equal 1100, sale.total_amount
      # 弁当2個に対してクーポンは最大2枚まで
      # 100円クーポン1枚(100円) + 50円クーポン1枚(50円) = 150円引き
      assert_equal 950, sale.final_amount
      assert_equal 2, sale.sale_discounts.count

      fifty = sale.sale_discounts.find_by(discount: discounts(:fifty_yen_discount))
      assert_equal 50, fifty.discount_amount
      assert_equal 1, fifty.quantity

      hundred = sale.sale_discounts.find_by(discount: discounts(:hundred_yen_discount))
      assert_equal 100, hundred.discount_amount
      assert_equal 1, hundred.quantity
    end

    # ===== 在庫減算 =====

    test "弁当2個の販売記録で在庫が2個減る" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      assert_changes -> { inventory.reload.stock }, from: inventory.stock, to: inventory.stock - 2 do
        record_sale([
          { catalog: catalogs(:daily_bento_a), quantity: 2 }
        ])
      end
    end

    test "弁当3個+サラダ2個の販売記録でそれぞれの在庫が減る" do
      inventory_a = daily_inventories(:city_hall_bento_a_today)
      inventory_salad = daily_inventories(:city_hall_salad_today)

      assert_difference -> { inventory_a.reload.stock }, -3 do
        assert_difference -> { inventory_salad.reload.stock }, -2 do
          record_sale([
            { catalog: catalogs(:daily_bento_a), quantity: 3 },
            { catalog: catalogs(:salad), quantity: 2 }
          ])
        end
      end
    end

    # ===== エラー ─ 在庫不足 =====

    test "在庫以上の数量を販売記録しようとすると在庫不足エラーになる" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      assert_raises DailyInventory::InsufficientStockError do
        record_sale([
          { catalog: catalogs(:daily_bento_a), quantity: inventory.stock + 100 }
        ])
      end
    end

    test "在庫が登録されていない商品を販売記録しようとするとエラーになる" do
      CatalogPrice.create!(
        catalog: catalogs(:discontinued_bento),
        kind: :regular,
        price: 400,
        effective_from: 1.month.ago
      )

      assert_raises ActiveRecord::RecordNotFound do
        record_sale([
          { catalog: catalogs(:discontinued_bento), quantity: 1 }
        ])
      end
    end

    # ===== エラー ─ 価格未設定 =====

    test "価格未設定の商品(味噌汁)を販売記録しようとするとエラーになる" do
      assert_raises Errors::MissingPriceError do
        record_sale([
          { catalog: catalogs(:miso_soup), quantity: 1 }
        ])
      end
    end

    test "価格未設定の商品を含む販売ではSaleもSaleItemも作成されず在庫も変わらない" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      assert_no_difference [ "Sale.count", "SaleItem.count" ] do
        assert_no_changes -> { inventory.reload.stock } do
          assert_raises Errors::MissingPriceError do
            record_sale([
              { catalog: catalogs(:daily_bento_a), quantity: 1 },
              { catalog: catalogs(:miso_soup), quantity: 1 }
            ])
          end
        end
      end
    end

    # ===== トランザクション整合性 =====

    test "在庫なし商品を含む販売ではSaleもSaleItemも作成されず在庫も変わらない" do
      inventory = daily_inventories(:city_hall_bento_a_today)

      CatalogPrice.create!(
        catalog: catalogs(:discontinued_bento),
        kind: :regular,
        price: 400,
        effective_from: 1.month.ago
      )

      assert_no_difference [ "Sale.count", "SaleItem.count" ] do
        assert_no_changes -> { inventory.reload.stock } do
          assert_raises ActiveRecord::RecordNotFound do
            record_sale([
              { catalog: catalogs(:daily_bento_a), quantity: 1 },
              { catalog: catalogs(:discontinued_bento), quantity: 1 }
            ])
          end
        end
      end
    end

    private

    def record_sale(items_params, discount_quantities: {})
      Sales::Recorder.new.record(
        {
          location: locations(:city_hall),
          customer_type: :staff,
          employee: employees(:verified_employee)
        },
        items_params,
        discount_quantities: discount_quantities
      )
    end
  end
end
