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
    bento_quantity(sale_items) > 0
  end

  # 最大適用可能枚数を計算
  # Requirement 13.2, 13.8: 弁当の種類数ではなく、個数ベースでカウント
  # @param sale_items [Array<Hash>] 販売明細
  # @return [Integer] 弁当の合計個数 × max_per_bento_quantity
  def max_applicable_quantity(sale_items)
    bento_quantity(sale_items) * max_per_bento_quantity
  end

  # 割引額を計算
  # @param sale_items [Array<Hash>] 販売明細
  # @return [Integer] 最大適用可能枚数 × 1枚あたりの割引額
  def calculate_discount(sale_items)
    max_applicable_quantity(sale_items) * amount_per_unit
  end

  private

  # 弁当の合計個数をカウント
  # Requirement 13.2, 13.8: 弁当の種類数ではなく、個数ベースでカウント
  # 例: 日替わりA 3個 + 日替わりB 2個 = 5個
  def bento_quantity(sale_items)
    sale_items
      .select { |item| item[:catalog].category == "bento" }
      .sum { |item| item[:quantity] }
  end
end
