class CreateSaleDiscounts < ActiveRecord::Migration[8.1]
  ##
  # Creates the `sale_discounts` table with foreign keys, columns, timestamps, and a composite unique index.
  # The table links sales to discounts and enforces:
  # - a non-null `sale` reference with `on_delete: :cascade`,
  # - a non-null `discount` reference with `on_delete: :restrict`,
  # - a non-null integer `discount_amount`,
  # and a unique index on `[sale_id, discount_id]` named `"idx_sale_discounts_unique"` to prevent applying the same discount to a sale more than once.
  def change
    create_table :sale_discounts do |t|
      # Task 9.1: 外部キー制約
      # - sale が削除されたら関連する SaleDiscount も削除 (cascade)
      # - discount が削除されることは想定しない (restrict)
      t.references :sale, null: false, foreign_key: { on_delete: :cascade }
      t.references :discount, null: false, foreign_key: { on_delete: :restrict }

      # Task 9.1: 割引適用額
      t.integer :discount_amount, null: false

      t.timestamps
    end

    # Task 9.3: ユニークインデックス作成
    # 同じ販売に同じ割引を複数回適用することを防止
    add_index :sale_discounts, [ :sale_id, :discount_id ],
              unique: true,
              name: "idx_sale_discounts_unique"
  end
end