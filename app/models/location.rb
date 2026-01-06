class Location < ApplicationRecord
  enum :status, { active: 0, inactive: 1 }

  validates :name, presence: true, uniqueness: true
end
