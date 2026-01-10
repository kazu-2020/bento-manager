class CreateRefunds < ActiveRecord::Migration[8.1]
  def change
    create_table :refunds, comment: "返金記録" do |t|
      t.references :original_sale, null: false, foreign_key: { to_table: :sales, on_delete: :restrict }, comment: "元の販売ID"
      t.references :corrected_sale, null: true, foreign_key: { to_table: :sales, on_delete: :restrict }, comment: "修正後の販売ID（全額返金の場合は null）"
      t.references :employee, null: true, foreign_key: { on_delete: :nullify }, comment: "返金処理担当者"
      t.datetime :refund_datetime, null: false, comment: "返金日時"
      t.integer :amount, null: false, comment: "返金額"
      t.string :reason, null: false, comment: "返金理由"
      t.timestamps
    end
  end
end
