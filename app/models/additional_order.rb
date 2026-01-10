class AdditionalOrder < ApplicationRecord
  # ===== アソシエーション =====
  belongs_to :location
  belongs_to :catalog
  belongs_to :employee, optional: true

  # ===== バリデーション =====
  validates :order_at, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }

  # ===== クラスメソッド =====

  # 追加発注を作成し、在庫を加算する
  #
  # @param attributes [Hash] AdditionalOrder の属性
  # @return [AdditionalOrder] 作成された追加発注レコード
  # @raise [ActiveRecord::RecordInvalid] バリデーション失敗時
  def self.create_with_inventory!(attributes)
    transaction do
      order = create!(attributes)

      inventory = DailyInventory.find_or_create_by!(
        location: order.location,
        catalog: order.catalog,
        inventory_date: order.order_at.to_date
      )

      inventory.increment_stock!(order.quantity)
      order
    end
  end
end
