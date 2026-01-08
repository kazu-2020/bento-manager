class CreateSaleItems < ActiveRecord::Migration[8.1]
  ##
  # Create the `sale_items` table with required columns, foreign key constraints, timestamps, and a composite index.
  #
  # The table includes:
  # - `sale` reference (not null) with a foreign key that cascades on delete.
  # - `catalog` reference (not null) with a foreign key that restricts on delete.
  # - `catalog_price` reference (not null) with a foreign key that restricts on delete.
  # - `quantity`, `unit_price`, and `line_total` as non-null integers.
  # - `sold_at` as a non-null datetime.
  # - automatic `created_at` and `updated_at` timestamps.
  #
  # Adds a composite index on [:sale_id, :catalog_id] named "idx_sale_items_sale_catalog".
  def change
    create_table :sale_items do |t|
      t.references :sale, null: false, foreign_key: { on_delete: :cascade }
      t.references :catalog, null: false, foreign_key: { on_delete: :restrict }
      t.references :catalog_price, null: false, foreign_key: { on_delete: :restrict }
      t.integer :quantity, null: false
      t.integer :unit_price, null: false
      t.integer :line_total, null: false
      t.datetime :sold_at, null: false

      t.timestamps
    end

    # Task 8.3: 複合インデックス作成
    # 注: t.references が自動的に単一カラムインデックスを作成するため、
    #     ここでは複合インデックスのみを追加
    add_index :sale_items, [ :sale_id, :catalog_id ], name: "idx_sale_items_sale_catalog"
  end
end