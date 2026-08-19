class Discount < ApplicationRecord
  include ValidPeriod

  has_many :sale_discounts, dependent: :restrict_with_exception
  has_many :sales, through: :sale_discounts

  delegated_type :discountable, types: %w[Coupon], autosave: true
  delegate :applicable?, :max_applicable_quantity, to: :discountable

  validates :name, presence: true

  # 割引額を計算
  # @param sale_items [Array<Hash>] 販売明細 [{ catalog: Catalog, quantity: Integer }, ...]
  # @return [Integer] 割引額（適用不可の場合は 0）
  def calculate_discount(sale_items = [])
    return 0 unless applicable?(sale_items)

    discountable.calculate_discount(sale_items)
  end
end
