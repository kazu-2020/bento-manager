class Catalog < ApplicationRecord
  # ===== アソシエーション =====
  # 関連レコードが存在する場合は削除を禁止（DB レベルでも ON DELETE RESTRICT）
  has_one  :discontinuation, class_name: "CatalogDiscontinuation", dependent: :restrict_with_error
  has_many :prices, class_name: "CatalogPrice", dependent: :restrict_with_error
  has_many :pricing_rules, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id", dependent: :restrict_with_error
  has_many :active_pricing_rules, -> { active }, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id"
  has_many :daily_inventories, dependent: :restrict_with_error
  has_many :sale_items, dependent: :restrict_with_error
  has_many :additional_orders, dependent: :restrict_with_error

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

  # 指定した種別の有効な価格を取得（存在しない場合は nil）
  # @param kind [String, Symbol] 価格種別 ('regular' | 'bundle')
  # @param at [Time] 基準日時（デフォルト: 現在）
  # @return [CatalogPrice, nil]
  def price_by_kind(kind, at: Time.current)
    prices.price_by_kind(kind: kind, at: at)
  end

  # 指定した種別の価格が存在するか
  # @param kind [String, Symbol] 価格種別 ('regular' | 'bundle')
  # @param at [Time] 基準日時（デフォルト: 現在）
  # @return [Boolean]
  def price_exists?(kind, at: Time.current)
    price_by_kind(kind, at: at).present?
  end

  # 指定した種別の価格を更新（履歴管理付き）
  # 既存価格がある場合は effective_until を設定して終了し、新しい価格を作成
  # @param kind [String, Symbol] 価格種別 ('regular' | 'bundle')
  # @param price [Integer] 新しい価格
  # @return [CatalogPrice] 作成された新しい価格レコード
  # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
  def update_price!(kind:, price:)
    current_price = price_by_kind(kind)
    new_price = prices.build(kind: kind, price: price, effective_from: Time.current)

    transaction do
      current_price&.update!(effective_until: Time.current)
      new_price.save!
    end

    new_price
  end

  # 提供終了かどうかを判定
  def discontinued?
    discontinuation.present?
  end

  # 指定した日付で有効な価格ルールを取得
  # @param date [Date] 基準日（デフォルト: 今日）
  # @return [ActiveRecord::Relation<CatalogPricingRule>]
  def active_pricing_rules_at(date = Date.current)
    pricing_rules.active_at(date)
  end
end
