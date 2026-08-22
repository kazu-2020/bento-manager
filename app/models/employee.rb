class Employee < ApplicationRecord
  include Rodauth::Rails.model(:employee)

  has_many :sales, dependent: :nullify
  has_many :voided_sales, class_name: "Sale", foreign_key: "voided_by_employee_id", dependent: :nullify
  has_many :refunds, dependent: :nullify
  has_many :additional_orders, dependent: :nullify

  enum :status, { verified: 2, closed: 3 }, validate: true

  # アカウント名のユニーク性は、閉鎖したアカウントを除外して検証する。
  # データベースの部分ユニークインデックス (status != 3) と同じ式である。
  # これにより閉鎖したアカウントは同じアカウント名を持つことができ、
  # そのアカウント名は新しい従業員が再び使える。
  validates :username, presence: true,
    format: { with: /\A[a-zA-Z0-9_]+\z/ },
    uniqueness: {
      conditions: -> { where.not(status: :closed) },
      case_sensitive: false
    }

  # 新規作成時はパスワード必須、更新時は任意
  validates :password, presence: true, on: :create
end
