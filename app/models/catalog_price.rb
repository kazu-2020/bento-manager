class CatalogPrice < ApplicationRecord
  belongs_to :catalog
  has_many :sale_items, dependent: :restrict_with_error

  enum :kind, { regular: 0, bundle: 1 }, validate: true

  validates :kind, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
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

  def self.current_price_by_kind(kind)
    by_kind(kind).current.order(effective_from: :desc).first
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
