class Location < ApplicationRecord
  enum :status, { active: 0, inactive: 1 }, validate: true

  validates :name, presence: true, uniqueness: true
end
