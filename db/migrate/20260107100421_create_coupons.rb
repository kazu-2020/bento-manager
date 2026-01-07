class CreateCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :coupons, comment: "クーポンマスタ" do |t|
      t.string :description, null: false, comment: "クーポン説明（例: 50円割引クーポン）"
      t.integer :amount_per_unit, null: false, comment: "1枚あたりの割引額（円）"
      t.integer :max_per_bento_quantity, null: false, comment: "弁当1個あたりの最大適用枚数"

      t.timestamps
    end
  end
end
