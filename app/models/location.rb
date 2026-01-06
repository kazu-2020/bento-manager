class Location < ApplicationRecord
  enum :status, { active: 0, inactive: 1 }

  default_scope { where(status: :active) }

  validates :name, presence: true, uniqueness: true

  def deactivate
    update(status: :inactive)
  end

  def activate
    update(status: :active)
  end
end
