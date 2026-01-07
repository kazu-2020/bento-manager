class CreateDailyInventories < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_inventories, comment: "販売先ごとの日次在庫" do |t|
      t.references :location, null: false, foreign_key: { on_delete: :restrict }, comment: "販売先"
      t.references :catalog, null: false, foreign_key: { on_delete: :restrict }, comment: "商品"
      t.date :inventory_date, null: false, comment: "在庫日"
      t.integer :stock, null: false, default: 0, comment: "在庫数"
      t.integer :reserved_stock, null: false, default: 0, comment: "予約済み在庫数（将来利用）"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    # Task 6.3: インデックス作成
    add_index :daily_inventories, [ :location_id, :catalog_id, :inventory_date ],
              unique: true, name: "idx_daily_inventories_location_catalog_date"
    add_index :daily_inventories, :location_id, name: "idx_daily_inventories_location"
  end
end
