class CatalogPrice < ApplicationRecord
  belongs_to :catalog

  enum :kind, { regular: 0, bundle: 1 }, validate: true

  validates :kind, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :effective_from, presence: true

  scope :current, -> {
    where(effective_from: ..Time.current)
      .merge(
        where(effective_until: nil).or(where(effective_until: Time.current..))
      )
  }
  scope :by_kind, ->(kind) { where(kind: kind) }

  def self.current_price_by_kind(catalog_id, kind)
    where(catalog_id: catalog_id)
      .by_kind(kind)
      .current
      .order(effective_from: :desc)
      .first
  end
end
