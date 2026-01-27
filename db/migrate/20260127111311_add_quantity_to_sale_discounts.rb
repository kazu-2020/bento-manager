class AddQuantityToSaleDiscounts < ActiveRecord::Migration[8.1]
  def change
    add_column :sale_discounts, :quantity, :integer, null: false, default: 1,
      comment: "クーポン使用枚数（デフォルト: 1枚）"
  end
end
