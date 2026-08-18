class RemoveRedundantIndexes < ActiveRecord::Migration[8.1]
  # 複合インデックスの左端プレフィックスと重複する単独インデックスを削除する。
  # SQLite は複合インデックスの左端プレフィックスを単独インデックスとして利用できるため、
  # これらは書き込みコストと DB サイズを消費するだけで参照されない。
  #
  # index_daily_inventories_on_catalog_id は削除対象外。複合インデックスが
  # (location_id, catalog_id, inventory_date) であり catalog_id が左端ではないため冗長ではない。
  def change
    # idx_sales_location_datetime (location_id, sale_datetime) がカバーする
    remove_index :sales, :location_id, name: "index_sales_on_location_id"

    # idx_sale_items_sale_catalog (sale_id, catalog_id) がカバーする
    remove_index :sale_items, :sale_id, name: "index_sale_items_on_sale_id"

    # idx_sale_discounts_unique (sale_id, discount_id) がカバーする
    remove_index :sale_discounts, :sale_id, name: "index_sale_discounts_on_sale_id"

    # idx_catalog_prices_catalog_kind (catalog_id, kind) がカバーする
    remove_index :catalog_prices, :catalog_id, name: "index_catalog_prices_on_catalog_id"
  end
end
