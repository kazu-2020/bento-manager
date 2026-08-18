class Sale < ApplicationRecord
  class AlreadyVoidedError < StandardError; end
  class NotTodaysSaleError < StandardError; end

  belongs_to :location
  belongs_to :employee, optional: true
  belongs_to :voided_by_employee, class_name: "Employee", optional: true
  belongs_to :corrected_from_sale, class_name: "Sale", optional: true
  has_one :correction_sale, class_name: "Sale", foreign_key: "corrected_from_sale_id"
  has_many :items, class_name: "SaleItem", dependent: :destroy
  has_many :sale_discounts, dependent: :destroy
  has_many :discounts, through: :sale_discounts
  has_many :refunds, foreign_key: "original_sale_id", dependent: :restrict_with_error

  enum :status,        { completed: 0, voided: 1 }, validate: true
  enum :customer_type, { staff: 0, citizen: 1 },    validate: true

  scope :in_period, ->(from, to) { where(sale_datetime: from..to) }
  scope :at_location, ->(location) { where(location: location) }

  validates :sale_datetime, presence: true
  validates :customer_type, presence: true
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :final_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :voided_at,          presence: true, if: :voided?
  validates :voided_by_employee, presence: true, if: :voided?

  # 販売開始済みかどうかを判定する
  #
  # 販売開始とは、その販売先でその日の最初の販売が確定した時点を指す。
  # 取消済みの販売も対象に含める。返品や差額精算で販売開始の事実は取り消されない。
  #
  # @param location [Location] 販売先
  # @param date [Date] 判定対象の日付
  # @return [Boolean] 販売開始済みなら true
  def self.started?(location:, date: Date.current)
    at_location(location).where(sale_datetime: date.all_day).exists?
  end

  # 在庫の復元は元の販売日、修正カートの母集合と修正後の販売の減算は当日を
  # 基準にする。この 2 つの基準日がずれるため、当日の販売にしか行えない
  #
  # @return [Boolean]
  def sold_today?
    sale_datetime.today?
  end

  # 差額精算の対象にできるか。当日でも取り消し済みの販売は二度は精算できない
  #
  # コントローラーと Sales::Refunder は断る理由ごとに案内も例外も変えるため
  # sold_today? / voided? を個別に見る。こちらは理由を要らない画面のための述語
  #
  # @return [Boolean]
  def refundable?
    completed? && sold_today?
  end

  # 販売を取り消す
  #
  # 取消済みかどうかの判定は、必ずトランザクション内で reload してから行う
  # （with_lock がそれを担う）。コントローラで読み込んだ sale をそのまま
  # 判定すると、同じ販売を読み込んだ 2 つのリクエストが並行して差額精算に
  # 入ったとき、どちらの `voided?` も false のままガードを通過し、在庫の
  # 二重復元と Refund の二重作成が起きる。
  # SQLite では with_lock は行ロックにならないが、それでもこの判定が直列化
  # される理由は docs/adr/0003-sqlite-concurrency-control.md を参照。
  #
  # @param voided_by [Employee] 取消担当者
  # @return [Boolean] `true` if the record was updated.
  # @raise [AlreadyVoidedError] if the sale is already voided.
  def void!(voided_by:)
    with_lock do
      raise AlreadyVoidedError, "この販売は既に取り消されています" if voided?

      update!(
        status: :voided,
        voided_at: Time.current,
        voided_by_employee: voided_by
      )
    end
  end
end
