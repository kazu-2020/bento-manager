class Employee < ApplicationRecord
  include Rodauth::Rails.model(:employee)
  enum :status, { unverified: 1, verified: 2, closed: 3 }

  # パスワード確認用の仮想属性
  attr_accessor :password_confirmation

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
  validate :password_confirmation_matches, if: -> { password.present? && password_confirmation.present? }

  private

  def password_confirmation_matches
    if password != password_confirmation
      errors.add(:password_confirmation, :confirmation, attribute: Employee.human_attribute_name(:password))
    end
  end
end
