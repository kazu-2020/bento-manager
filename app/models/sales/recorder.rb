# 販売記録 PORO
# Sale と SaleItem の作成、在庫減算を一括で行う
module Sales
  class Recorder
    # 販売を記録し、在庫を減算する
    #
    # PriceCalculator で価格計算と価格存在検証を行い、
    # その結果を使って Sale/SaleItem/SaleDiscount を作成する。
    #
    # @param sale_params [Hash] Sale 作成に使用する属性
    #   - :location [Location] 販売先
    #   - :customer_type [Symbol] 顧客区分
    #   - :employee [Employee] 販売員
    # @param items_params [Array<Hash>] 各アイテムの属性配列
    #   - :catalog [Catalog] 商品
    #   - :quantity [Integer] 数量
    # @param discount_ids [Array<Integer>] 適用する割引の ID リスト
    # @return [Sale] 作成された Sale（関連する SaleItem レコードを含む）
    # @raise [Errors::MissingPriceError] 価格未設定時
    # @raise [DailyInventory::InsufficientStockError] 在庫不足時
    # @raise [ActiveRecord::RecordNotFound] 対応する DailyInventory レコードが見つからない場合
    def record(sale_params, items_params, discount_ids: [])
      now = Time.current

      # Step 1: 価格計算（価格存在検証含む）- トランザクション開始前に実行
      price_result = calculate_prices(items_params, discount_ids, now)

      # Step 2: トランザクション内で Sale/SaleItem/SaleDiscount 作成と在庫減算
      Sale.transaction do
        sale = create_sale(sale_params, price_result, now)
        create_sale_items(sale, price_result[:items_with_prices], now)
        create_sale_discounts(sale, price_result[:discount_details])

        sale
      end
    end

    private

    # 価格計算を実行（PriceCalculator 経由）
    #
    # @param items_params [Array<Hash>] 販売明細のパラメータ（catalog, quantity を含む）
    # @param discount_ids [Array<Integer>] 割引 ID リスト
    # @param calculation_time [Time] 計算基準時刻
    # @return [Hash] PriceCalculator.calculate の結果
    # @raise [Errors::MissingPriceError] 価格未設定時
    def calculate_prices(items_params, discount_ids, calculation_time)
      calculator = Sales::PriceCalculator.new(items_params, discount_ids: discount_ids, calculation_time: calculation_time)
      calculator.calculate
    rescue Errors::MissingPriceError => e
      Rails.logger.error("[Sales::Recorder] 価格未設定エラー: #{e.message}")
      raise
    end

    # Sale を作成
    #
    # @param sale_params [Hash] Sale 作成パラメータ
    # @param price_result [Hash] 価格計算結果
    # @param now [Time] 販売日時
    # @return [Sale] 作成された Sale
    def create_sale(sale_params, price_result, now)
      Sale.create!(
        sale_params.merge(
          sale_datetime: now,
          total_amount: price_result[:subtotal],
          final_amount: price_result[:final_total]
        )
      )
    end

    # SaleItem を作成し、在庫を減算
    #
    # @param sale [Sale] 販売レコード
    # @param items_with_prices [Array<Hash>] 価格情報を付加したアイテム
    # @param now [Time] 販売日時
    def create_sale_items(sale, items_with_prices, now)
      items_with_prices.each do |item|
        sale_item = sale.items.create!(
          catalog: item[:catalog],
          catalog_price_id: item[:catalog_price_id],
          quantity: item[:quantity],
          unit_price: item[:unit_price],
          sold_at: now
        )
        decrement_inventory(sale, sale_item)
      end
    end

    # SaleDiscount を作成
    #
    # @param sale [Sale] 販売レコード
    # @param discount_details [Array<Hash>] 割引詳細
    def create_sale_discounts(sale, discount_details)
      discount_details
        .select { |detail| detail[:applicable] }
        .each do |detail|
          sale.sale_discounts.create!(
            discount_id: detail[:discount_id],
            discount_amount: detail[:discount_amount]
          )
        end
    end

    # 指定された販売明細に対応する日次在庫を検索し、販売数量分の在庫を減算する
    #
    # @param sale [Sale] アイテムを所有する販売（ロケーションと日付の解決に使用）
    # @param sale_item [SaleItem] 在庫から減算する数量を持つアイテム
    # @raise [ActiveRecord::RecordNotFound] 販売のロケーション、アイテムのカタログ、販売日に一致する DailyInventory がない場合
    # @raise [DailyInventory::InsufficientStockError] 在庫が減算に必要な数量を満たさない場合
    def decrement_inventory(sale, sale_item)
      inventory = DailyInventory.find_by!(
        location_id: sale.location_id,
        catalog_id: sale_item.catalog_id,
        inventory_date: sale_item.sold_at.to_date
      )
      inventory.decrement_stock!(sale_item.quantity)
    end
  end
end
