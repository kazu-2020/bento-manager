# 販売記録 PORO
# Sale と SaleItem の作成、在庫減算を一括で行う
module Sales
  class Recorder
    # 販売を記録し、在庫を減算する
    #
    # 単一のデータベーストランザクション内で販売とその関連アイテムを記録する。
    # `sale_params` から Sale を作成し、`items_params` の各要素から SaleItem を作成し、
    # 各アイテムに対応する日次在庫を減算する。
    #
    # @param sale_params [Hash] Sale 作成に使用する属性
    # @param items_params [Array<Hash>] 各 SaleItem の属性配列
    # @return [Sale] 作成された Sale（関連する SaleItem レコードを含む）
    # @raise [DailyInventory::InsufficientStockError] 在庫不足時
    # @raise [ActiveRecord::RecordNotFound] 対応する DailyInventory レコードが見つからない場合
    def record(sale_params, items_params)
      Sale.transaction do
        sale = Sale.create!(sale_params)

        items_params.each do |item_params|
          sale_item = sale.sale_items.create!(item_params)
          decrement_inventory(sale, sale_item)
        end

        sale
      end
    end

    private

    # 指定された販売アイテムに対応する DailyInventory を検索し、販売数量分の在庫を減算する
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
