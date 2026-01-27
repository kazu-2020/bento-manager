class RemoveMaxPerBentoQuantityFromCoupons < ActiveRecord::Migration[8.1]
  def up
    remove_column :coupons, :max_per_bento_quantity
  end

  def down
    add_column :coupons, :max_per_bento_quantity, :integer, null: false, default: 1,
      comment: "弁当1個あたりの最大適用枚数"
  end
end
