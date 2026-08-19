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

  # 適用期間の状態。valid_from / valid_until と当日の関係から導出する
  def status
    return :expired if expired?
    return :upcoming if upcoming?

    :active
  end

  def expired?
    valid_until.present? && valid_until < Date.current
  end

  def upcoming?
    valid_from > Date.current
  end
end
