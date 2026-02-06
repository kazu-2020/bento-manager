# 販売・割引中間テーブル
# 販売に適用された割引を記録し、監査トレイルを提供する
class SaleDiscount < ApplicationRecord
  belongs_to :sale
  belongs_to :discount

  validates :discount_amount, presence: true, numericality: { greater_than: 0 }
  validates :quantity,        presence: true, numericality: { greater_than: 0 }

  # 同じ販売に同じ割引を複数回適用することを防止
  validates :discount_id, uniqueness: {
    scope: :sale_id,
    message: "同じ割引を複数回適用できません"
  }
end
