class CreateAdditionalOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :additional_orders, comment: "追加発注記録" do |t|
      t.references :location, null: false, foreign_key: { on_delete: :restrict }, comment: "販売先"
      t.references :catalog, null: false, foreign_key: { on_delete: :restrict }, comment: "商品"
      t.datetime :order_at, null: false, comment: "発注日時"
      t.integer :quantity, null: false, comment: "発注数量"
      t.references :employee, foreign_key: { on_delete: :nullify }, comment: "発注担当者"

      t.timestamps
    end
  end
end
