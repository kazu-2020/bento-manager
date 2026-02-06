class CatalogPrice < ApplicationRecord
  belongs_to :catalog
  has_many   :sale_items, dependent: :restrict_with_error

  enum :kind, { regular: 0, bundle: 1 }, validate: true

  validates :kind,           presence: true
  validates :price,          presence: true, numericality: { greater_than: 0 }
  validates :effective_from, presence: true

  validate :valid_date_range

  scope :effective_at, ->(date) {
    where(effective_from: ..date)
      .merge(
        where(effective_until: nil).or(where(effective_until: date..))
      )
  }
  scope :current, -> { effective_at(Time.current) }
  scope :by_kind, ->(kind) { where(kind: kind) }

  def self.price_by_kind(kind:, at: Time.current)
    by_kind(kind).effective_at(at).order(effective_from: :desc).first
  end

  # 新しい価格を作成し、既存の有効な価格があれば終了させる
  # @param catalog [Catalog] 対象カタログ
  # @param kind [String, Symbol] 価格種別
  # @param price [Integer] 新しい価格
  # @return [CatalogPrice] 作成された新しい価格レコード
  # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
  def self.create_with_history!(catalog:, kind:, price:)
    current_price = catalog.price_by_kind(kind)
    new_price = new(catalog: catalog, kind: kind, price: price, effective_from: Time.current)

    transaction do
      current_price&.update!(effective_until: Time.current)
      new_price.save!
    end

    new_price
  end

  private

  # effective_until が effective_from より後であることを検証
  def valid_date_range
    return if effective_from.blank? || effective_until.blank?

    if effective_until <= effective_from
      errors.add(:effective_until, "は適用開始日時より後の日時を指定してください")
    end
  end
end
