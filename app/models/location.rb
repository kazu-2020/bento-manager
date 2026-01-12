class Location < ApplicationRecord
  # ===== アソシエーション =====
  has_many :daily_inventories, dependent: :restrict_with_error
  has_many :sales, dependent: :restrict_with_error
  has_many :additional_orders, dependent: :restrict_with_error

  # ===== Enum =====
  enum :status, { active: 0, inactive: 1 }, validate: true

  # ===== Scope =====
  scope :display_order, -> { in_order_of(:status, %w[active inactive]).order(:id) }

  # ===== バリデーション =====
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
