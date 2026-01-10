class Catalog < ApplicationRecord
  # ===== アソシエーション =====
  # 関連レコードが存在する場合は削除を禁止（DB レベルでも ON DELETE RESTRICT）
  has_one  :discontinuation, class_name: "CatalogDiscontinuation", dependent: :restrict_with_error
  has_many :prices, class_name: "CatalogPrice", dependent: :restrict_with_error
  has_many :pricing_rules, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id", dependent: :restrict_with_error
  has_many :active_pricing_rules, -> { active }, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id"
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

  # 指定した種別の現在有効な価格を取得（存在しない場合は例外）
  def price_by_kind(kind)
    prices.by_kind(kind).current.order(effective_from: :desc).first!
  end

  # 指定した種別の価格が存在するか
  # @param kind [String, Symbol] 価格種別 ('regular' | 'bundle')
  # @param at [Date] 基準日（デフォルト: 今日）
  # @return [Boolean]
  def price_exists?(kind, at: Date.current)
    prices.by_kind(kind).effective_at(at).exists?
  end

  # 提供終了かどうかを判定
  def discontinued?
    discontinuation.present?
  end
end
