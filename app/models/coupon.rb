class Coupon < ApplicationRecord
  # ===== アソシエーション =====
  has_one :discount, as: :discountable, touch: true

  # ===== バリデーション =====
  validates :description, presence: true
  validates :amount_per_unit, presence: true, numericality: { greater_than: 0 }
  validates :max_per_bento_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # ===== ビジネスロジック =====

  # クーポンが適用可能かどうかを判定
  # @param sale_items [Array<Hash>] 販売明細 [{ catalog: Catalog, quantity: Integer }, ...]
  # @return [Boolean] 弁当が含まれている場合 true
  def applicable?(sale_items)
    bento_count(sale_items) > 0
  end

  # 最大適用可能枚数を計算
  # @param sale_items [Array<Hash>] 販売明細
  # @return [Integer] 弁当の種類数 × max_per_bento_quantity
  def max_applicable_quantity(sale_items)
    bento_count(sale_items) * max_per_bento_quantity
  end

  # 割引額を計算
  # @param sale_items [Array<Hash>] 販売明細
  # @return [Integer] 最大適用可能枚数 × 1枚あたりの割引額
  def calculate_discount(sale_items)
    max_applicable_quantity(sale_items) * amount_per_unit
  end

  private

  # 弁当の数をカウント（sale_items の中で category が bento のアイテム数）
  # Note: design.md の実装例に従い、sale_items.count を使用（種類数をカウント）
  # 将来的に quantity を考慮する場合は sum { |item| item[:quantity] } に変更
  def bento_count(sale_items)
    sale_items.count { |item| item[:catalog].category == "bento" }
  end
end
