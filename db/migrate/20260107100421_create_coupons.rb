class CreateCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :coupons, comment: "クーポンマスタ" do |t|
      t.integer :amount_per_unit, null: false, comment: "1枚あたりの割引額（円）"

      t.timestamps
    end
  end
end
