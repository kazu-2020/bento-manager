# 販売記録 PORO
# Sale と SaleItem の作成、在庫減算を一括で行う
module Sales
  class Recorder
    # 販売を記録し、在庫を減算する
    # @param sale_params [Hash] Sale の属性
    # @param items_params [Array<Hash>] SaleItem の属性配列
    # @return [Sale] 作成された Sale
    # @raise [DailyInventory::InsufficientStockError] 在庫不足時
    # @raise [ActiveRecord::RecordNotFound] 在庫レコード未存在時
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
