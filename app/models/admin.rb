class Admin < ApplicationRecord
  include Rodauth::Rails.model(:admin)
  enum :status, { unverified: 1, verified: 2, closed: 3 }, validate: true

  # アカウント名のユニーク性は、closedステータスを除外して検証
  # データベースの部分ユニークインデックス (status IN (1, 2)) と一致
  # これにより、closedアカウントは同じアカウント名を持つことができ、
  # closedアカウントのアカウント名は新しいアカウントで再利用可能
  validates :username, presence: true,
    format: { with: /\A[a-zA-Z0-9_]+\z/ },
    uniqueness: {
      conditions: -> { where.not(status: :closed) },
      case_sensitive: false
    }
end
