class RemoveMaxPerBentoQuantityFromCoupons < ActiveRecord::Migration[8.1]
  def change
    remove_column :coupons, :max_per_bento_quantity, :integer, null: false
  end
end
