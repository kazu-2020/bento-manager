class Catalog < ApplicationRecord
  # ===== アソシエーション =====
  # 関連レコードが存在する場合は削除を禁止（DB レベルでも ON DELETE RESTRICT）
  has_one  :discontinuation, class_name: "CatalogDiscontinuation", dependent: :restrict_with_error
  has_many :prices, class_name: "CatalogPrice", dependent: :restrict_with_error
  has_many :pricing_rules, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id", dependent: :restrict_with_error
  has_many :active_pricing_rules, -> { CatalogPricingRule.active }, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id"
  has_many :daily_inventories, dependent: :restrict_with_error
  has_many :sale_items, dependent: :restrict_with_error

  # ===== コールバック =====
  # 物理削除を禁止する
  # 背景: 商品カタログは販売履歴（SaleItem）から参照されるため、
  #       物理削除すると過去の販売データの整合性が失われる。
  #       提供終了する場合は CatalogDiscontinuation を作成して論理削除とする。
  before_destroy { throw :abort }

  # ===== スコープ =====
  # 販売可能な商品（提供終了記録がない）を取得
  scope :available, -> { where.missing(:discontinuation) }

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
