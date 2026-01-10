class Employee < ApplicationRecord
  include Rodauth::Rails.model(:employee)

  # ===== アソシエーション =====
  has_many :sales, dependent: :nullify
  has_many :voided_sales, class_name: "Sale", foreign_key: "voided_by_employee_id", dependent: :nullify
  has_many :refunds, dependent: :nullify

  # ===== Enum =====
  enum :status, { unverified: 1, verified: 2, closed: 3 }, validate: true

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
