class Employee < ApplicationRecord
  include Rodauth::Rails.model(:employee)
  enum :status, { unverified: 1, verified: 2, closed: 3 }

  # メールアドレスのユニーク性は、closedステータスを除外して検証
  # データベースの部分ユニークインデックス (status IN (1, 2)) と一致
  # これにより、closedアカウントは同じメールアドレスを持つことができ、
  # closedアカウントのメールアドレスは新しいアカウントで再利用可能
  validates :email, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: {
      conditions: -> { where.not(status: :closed) },
      case_sensitive: false
    }
  validates :name, presence: true

  # 新規作成時はパスワード必須、更新時は任意
  validates :password, presence: true, on: :create
end
