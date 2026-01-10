class CreateAdditionalOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :additional_orders do |t|
      # Task 12.1: 追加発注テーブル
      t.references :location, null: false, foreign_key: { on_delete: :restrict }
      t.references :catalog, null: false, foreign_key: { on_delete: :restrict }
      t.date :order_date, null: false
      t.time :order_time, null: false
      t.integer :quantity, null: false
      t.references :employee, foreign_key: { on_delete: :nullify }

      t.timestamps
    end
  end
end
