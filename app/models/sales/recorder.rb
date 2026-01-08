# 販売記録 PORO
# Sale と SaleItem の作成、在庫減算を一括で行う
module Sales
  class Recorder
    # 販売を記録し、在庫を減算する
    # @param sale_params [Hash] Sale の属性
    # @param items_params [Array<Hash>] SaleItem の属性配列
    # @return [Sale] 作成された Sale
    # @raise [DailyInventory::InsufficientStockError] 在庫不足時
    ##
    # Records a sale and its associated items within a single database transaction.
    # Creates a Sale from `sale_params`, creates each associated SaleItem from `items_params`,
    # and decrements the corresponding daily inventory for each item.
    # @param [Hash] sale_params - Attributes used to create the Sale.
    # @param [Array<Hash>] items_params - Array of attributes for each SaleItem.
    # @return [Sale] The created Sale with its associated SaleItem records.
    # @raise [DailyInventory::InsufficientStockError] If there is insufficient stock for any item.
    # @raise [ActiveRecord::RecordNotFound] If a required DailyInventory record cannot be found.
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

    ##
    # Locate the DailyInventory for the given sale item and decrement its stock by the item's sold quantity.
    # @param [Sale] sale - The sale that owns the item; used to resolve location and date.
    # @param [SaleItem] sale_item - The item whose quantity will be subtracted from inventory.
    # @raise [ActiveRecord::RecordNotFound] If no DailyInventory matches the sale's location, the item's catalog, and the sale date.
    # @raise [DailyInventory::InsufficientStockError] If the inventory does not have enough stock to cover the requested decrement.
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