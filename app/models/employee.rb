class Employee < ApplicationRecord
  include Rodauth::Rails.model(:employee)

  has_many :sales, dependent: :nullify
  has_many :voided_sales, class_name: "Sale", foreign_key: "voided_by_employee_id", dependent: :nullify
  has_many :refunds, dependent: :nullify
  has_many :additional_orders, dependent: :nullify

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

  # 新規作成時はパスワード必須、更新時は任意
  validates :password, presence: true, on: :create
end
