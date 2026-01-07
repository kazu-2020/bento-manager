class CreateSales < ActiveRecord::Migration[8.1]
  ##
  # Creates the `sales` table with its columns, constraints, foreign keys, and indexes.
  # The migration defines columns for location, sale_datetime, customer_type, total and final amounts,
  # optional employee association, status with default, voiding and correction audit fields, and timestamps.
  # It also adds foreign keys for `voided_by_employee_id` (to `employees`) and `corrected_from_sale_id` (self-referential),
  # and creates indexes on `(location_id, sale_datetime)`, `sale_datetime`, and `status`.
  def change
    create_table :sales, comment: "販売記録" do |t|
      t.references :location, null: false, foreign_key: true, comment: "販売先"
      t.datetime :sale_datetime, null: false, comment: "販売日時"
      t.integer :customer_type, null: false, comment: "顧客区分（0: staff, 1: citizen）"
      t.integer :total_amount, null: false, comment: "小計（割引前）"
      t.integer :final_amount, null: false, comment: "合計（割引後）"
      t.references :employee, null: true, foreign_key: true, comment: "販売担当者"
      t.integer :status, null: false, default: 0, comment: "状態（0: completed, 1: voided）"
      t.datetime :voided_at, null: true, comment: "取消日時"
      t.bigint :voided_by_employee_id, null: true, comment: "取消担当者ID"
      t.string :void_reason, null: true, comment: "取消理由"
      t.bigint :corrected_from_sale_id, null: true, comment: "元の販売ID（再販売の場合）"
      t.timestamps
    end

    add_foreign_key :sales, :employees, column: :voided_by_employee_id
    add_foreign_key :sales, :sales, column: :corrected_from_sale_id

    # Task 7.3: インデックス作成
    add_index :sales, [ :location_id, :sale_datetime ], name: "idx_sales_location_datetime"
    add_index :sales, :sale_datetime, name: "idx_sales_datetime"
    add_index :sales, :status, name: "idx_sales_status"
  end
end
