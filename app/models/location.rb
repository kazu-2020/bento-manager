class Location < ApplicationRecord
  has_many :daily_inventories, dependent: :restrict_with_error
  has_many :today_inventories,
           -> { where(inventory_date: Date.current) },
           class_name: "DailyInventory"
  has_many :sales, dependent: :restrict_with_error
  has_many :additional_orders, dependent: :restrict_with_error

  enum :status, { active: 0, inactive: 1 }, validate: true

  scope :display_order, -> { in_order_of(:status, %w[active inactive]).order(:name) }

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def has_today_inventory?
    today_inventories.any?
  end
end
