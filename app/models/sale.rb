class Sale < ApplicationRecord
  # ===== カスタムエラー =====
  class AlreadyVoidedError < StandardError; end

  # ===== アソシエーション =====
  belongs_to :location
  belongs_to :employee, optional: true
  belongs_to :voided_by_employee, class_name: "Employee", optional: true
  belongs_to :corrected_from_sale, class_name: "Sale", optional: true
  has_one :correction_sale, class_name: "Sale", foreign_key: "corrected_from_sale_id"
  has_many :items, class_name: "SaleItem", dependent: :destroy
  has_many :sale_discounts, dependent: :destroy
  has_many :discounts, through: :sale_discounts
  has_many :refunds, foreign_key: "original_sale_id", dependent: :restrict_with_error

  # ===== Enum =====
  enum :status, { completed: 0, voided: 1 }, validate: true
  enum :customer_type, { staff: 0, citizen: 1 }, validate: true

  # ===== バリデーション =====
  validates :location, presence: true
  validates :sale_datetime, presence: true
  validates :customer_type, presence: true
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :final_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # status が voided の場合の必須バリデーション
  validates :voided_at, presence: true, if: :voided?
  validates :voided_by_employee, presence: true, if: :voided?
  validates :void_reason, presence: true, if: :voided?

  # ===== インスタンスメソッド =====

  # 販売を取り消す
  # @param reason [String] 取消理由
  # @param voided_by [Employee] 取消担当者
  ##
  # Mark the sale as voided, recording the void reason and the employee who performed the void.
  # @param [String] reason - The reason for voiding the sale.
  # @param [Employee] voided_by - The employee who voided the sale.
  # @return [Boolean] `true` if the record was updated.
  # @raise [AlreadyVoidedError] if the sale is already voided.
  def void!(reason:, voided_by:)
    raise AlreadyVoidedError, "この販売は既に取り消されています" if voided?

    update!(
      status: :voided,
      voided_at: Time.current,
      voided_by_employee: voided_by,
      void_reason: reason
    )
  end
end
