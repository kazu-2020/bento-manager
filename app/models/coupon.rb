class Coupon < ApplicationRecord
  # ===== アソシエーション =====
  has_one :discount, as: :discountable, touch: true

  # ===== バリデーション =====
  validates :description, presence: true
  validates :amount_per_unit, presence: true, numericality: { greater_than: 0 }

  # ===== ビジネスロジック =====

  # クーポンが適用可能かどうかを判定
  # @param sale_items [Array<Hash>] 販売明細 [{ catalog: Catalog, quantity: Integer }, ...]
  # @return [Boolean] 弁当が含まれている場合 true
  def applicable?(sale_items)
    bento_quantity(sale_items) > 0
  end

  # 割引額を計算
  # @param sale_items [Array<Hash>] 販売明細（Discount#calculate_discount からの委譲インターフェースに準拠。
  #   固定額クーポンでは未使用だが、将来の割引タイプでは参照される想定）
  # @return [Integer] クーポン1枚あたりの固定割引額
  def calculate_discount(sale_items)
    amount_per_unit
  end

  # クーポンの最大適用枚数を返す
  # @param sale_items [Array<Hash>] 販売明細 [{ catalog: Catalog, quantity: Integer }, ...]
  # @return [Integer] 弁当の合計個数（= クーポン適用上限）
  def max_applicable_quantity(sale_items)
    bento_quantity(sale_items)
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
