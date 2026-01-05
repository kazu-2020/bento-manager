class Admin < ApplicationRecord
  include Rodauth::Rails.model(:admin)
  enum :status, { unverified: 1, verified: 2, closed: 3 }

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
end
