class Location < ApplicationRecord
  # ===== アソシエーション =====
  has_many :daily_inventories, dependent: :restrict_with_error
  has_many :sales, dependent: :restrict_with_error

  # ===== Enum =====
  enum :status, { active: 0, inactive: 1 }, validate: true

  # ===== バリデーション =====
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
