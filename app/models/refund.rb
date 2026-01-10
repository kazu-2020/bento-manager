class Refund < ApplicationRecord
  # ===== アソシエーション =====
  belongs_to :original_sale, class_name: "Sale"
  belongs_to :corrected_sale, class_name: "Sale", optional: true
  belongs_to :employee, optional: true

  # ===== バリデーション =====
  validates :original_sale, presence: true
  validates :refund_datetime, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reason, presence: true
end
