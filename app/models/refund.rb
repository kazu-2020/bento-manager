class Refund < ApplicationRecord
  belongs_to :original_sale,  class_name: "Sale"
  belongs_to :corrected_sale, class_name: "Sale", optional: true
  belongs_to :employee, optional: true

  validates :refund_datetime, presence: true
  validates :amount,          presence: true, numericality: { only_integer: true }
end
