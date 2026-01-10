class CreateRefunds < ActiveRecord::Migration[8.1]
  ##
  # Creates the `refunds` table for recording refund transactions.
  # This table stores the relationship between original voided sales and corrected sales,
  # along with refund amount and reason for auditing purposes.
  def change
    create_table :refunds, comment: "返金記録" do |t|
      t.bigint :original_sale_id, null: false, comment: "元の販売ID"
      t.bigint :corrected_sale_id, null: true, comment: "修正後の販売ID（全額返金の場合は null）"
      t.references :employee, null: true, foreign_key: true, comment: "返金処理担当者"
      t.datetime :refund_datetime, null: false, comment: "返金日時"
      t.integer :amount, null: false, comment: "返金額"
      t.string :reason, null: false, comment: "返金理由"
      t.timestamps
    end

    # 外部キー制約
    add_foreign_key :refunds, :sales, column: :original_sale_id
    add_foreign_key :refunds, :sales, column: :corrected_sale_id

    # Task 11.3: インデックス作成
    add_index :refunds, :original_sale_id, name: "idx_refunds_original_sale"
    add_index :refunds, :corrected_sale_id, name: "idx_refunds_corrected_sale"
  end
end
