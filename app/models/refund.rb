class Refund < ApplicationRecord
  belongs_to :original_sale,  class_name: "Sale"
  belongs_to :corrected_sale, class_name: "Sale", optional: true
  belongs_to :employee, optional: true

  validates :refund_datetime, presence: true
  validates :amount,          presence: true, numericality: { greater_than_or_equal_to: 0 }
end
