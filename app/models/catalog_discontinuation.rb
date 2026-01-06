class CatalogDiscontinuation < ApplicationRecord
  belongs_to :catalog

  validates :discontinued_at, presence: true
  validates :reason, presence: true
  validates :catalog_id, uniqueness: true
end
