class Location < ApplicationRecord
  enum :status, { active: 0, inactive: 1 }

  validates :name, presence: true, uniqueness: true

  scope :active_only, -> { where(status: :active) }
end
