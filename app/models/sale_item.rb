# Task 8.1-8.4: 販売明細モデル
# 販売時の商品、数量、単価、小計を記録し、在庫を自動減算する
class SaleItem < ApplicationRecord
  # ===== アソシエーション =====
  belongs_to :sale
  belongs_to :catalog
  belongs_to :catalog_price

  # ===== バリデーション (Task 8.2) =====
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :line_total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sold_at, presence: true

  # ===== コールバック =====
  before_validation :calculate_line_total
  after_create :decrement_inventory_stock

  private

  # line_total = unit_price * quantity を計算
  def calculate_line_total
    return unless unit_price.present? && quantity.present?
    self.line_total = unit_price * quantity
  end

  # Task 8.4: 在庫減算（販売時）
  # 販売先の当日在庫から数量を減算する
  def decrement_inventory_stock
    inventory = DailyInventory.find_by!(
      location_id: sale.location_id,
      catalog_id: catalog_id,
      inventory_date: sold_at.to_date
    )
    inventory.decrement_stock!(quantity)
  end
end
