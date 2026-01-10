class CreateDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :discounts, comment: "割引マスタ（delegated_type パターン）" do |t|
      t.references :discountable, polymorphic: true, null: false, index: { unique: true, name: "idx_discounts_discountable" }, comment: "割引種別"
      t.string :name, null: false, comment: "割引名称（例: 50円割引クーポン）"
      t.date :valid_from, null: false, comment: "有効開始日"
      t.date :valid_until, comment: "有効終了日（null=無期限）"

      t.timestamps
    end

    # Task 5.4: インデックス作成
    add_index :discounts, :name, name: "idx_discounts_name"
    add_index :discounts, [ :valid_from, :valid_until ], name: "idx_discounts_validity"
  end
end
