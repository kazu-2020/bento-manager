class Discount < ApplicationRecord
  # ===== アソシエーション =====
  delegated_type :discountable, types: %w[Coupon]

  # ===== 委譲 =====
  delegate :applicable?, to: :discountable

  # ===== スコープ =====
  # 現在有効な割引を取得（valid_from <= 今日 AND (valid_until が nil OR valid_until >= 今日)）
  scope :active, -> {
    where(valid_from: ..Date.current)
      .merge(
        where(valid_until: nil).or(where(valid_until: Date.current..))
      )
  }

  # ===== バリデーション =====
  validates :name, presence: true
  validates :valid_from, presence: true
  validate :valid_date_range

  # ===== ビジネスロジック =====

  # 割引額を計算
  # @param sale_items [Array<Hash>] 販売明細 [{ catalog: Catalog, quantity: Integer }, ...]
  # @return [Integer] 割引額（適用不可の場合は 0）
  def calculate_discount(sale_items = [])
    return 0 unless discountable.applicable?(sale_items)

    discountable.calculate_discount(sale_items)
  end

  private

  # 日付範囲の妥当性を検証
  # valid_until が設定されている場合、valid_from より後である必要がある
  def valid_date_range
    return if valid_from.blank? || valid_until.blank?

    if valid_until <= valid_from
      errors.add(:valid_until, "は有効開始日より後の日付を指定してください")
    end
  end
end
