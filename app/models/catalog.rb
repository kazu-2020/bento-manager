class Catalog < ApplicationRecord
  # ===== アソシエーション =====
  has_many :prices, class_name: "CatalogPrice", dependent: :destroy
  has_many :pricing_rules, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id", dependent: :destroy
  has_one :discontinuation, class_name: "CatalogDiscontinuation", dependent: :destroy

  # ===== Enum =====
  enum :category, { bento: 0, side_menu: 1 }, validate: true

  # ===== バリデーション =====
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :category, presence: true

  # ===== ビジネスロジック =====

  # 現在有効な価格を取得
  def current_price
    prices.current.order(effective_from: :desc).first
  end

  # 提供終了かどうかを判定
  def discontinued?
    discontinuation.present?
  end
end
