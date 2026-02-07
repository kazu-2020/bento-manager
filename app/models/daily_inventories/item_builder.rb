# frozen_string_literal: true

module DailyInventories
  class ItemBuilder
    def self.from_params(catalogs, submitted)
      catalogs.map do |catalog|
        attrs = submitted[catalog.id.to_s] || {}
        InventoryItem.new(
          **attrs.symbolize_keys.slice(:selected, :stock),
          catalog_id: catalog.id,
          catalog_name: catalog.name,
          category: catalog.category
        )
      end
    end

    def self.from_inventories(catalogs, inventories_by_catalog_id)
      catalogs.map do |catalog|
        inv = inventories_by_catalog_id[catalog.id]
        InventoryItem.new(
          catalog_id: catalog.id,
          catalog_name: catalog.name,
          category: catalog.category,
          selected: inv.present?,
          stock: inv&.stock || InventoryItem::DEFAULT_STOCK
        )
      end
    end
  end
end
