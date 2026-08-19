class Discount < ApplicationRecord
  has_many :sale_discounts, dependent: :restrict_with_exception
  has_many :sales, through: :sale_discounts

  delegated_type :discountable, types: %w[Coupon], autosave: true
  delegate :applicable?, :max_applicable_quantity, to: :discountable

  # 指定日時点で有効な割引を取得
  scope :active_at, ->(date) {
    where(valid_from: ..date)
      .merge(
        where(valid_until: nil).or(where(valid_until: date..))
      )
  }
  scope :active, -> { active_at(Date.current) }

  validates :name, presence: true
  validates :valid_from, presence: true

  validate :valid_date_range

  # 割引額を計算
  # @param sale_items [Array<Hash>] 販売明細 [{ catalog: Catalog, quantity: Integer }, ...]
  # @return [Integer] 割引額（適用不可の場合は 0）
  def calculate_discount(sale_items = [])
    return 0 unless applicable?(sale_items)

    discountable.calculate_discount(sale_items)
  end

  # 適用期間の状態。valid_from / valid_until と当日の関係から導出する
  def status
    return :expired if expired?
    return :upcoming if upcoming?

    :active
  end

  def expired?
    valid_until.present? && valid_until < Date.current
  end

  def upcoming?
    valid_from > Date.current
  end

  private

  # valid_until が valid_from 以降であることを検証
  # valid_from / valid_until は date かつ active_at が両端 inclusive のため、
  # 同日指定は「その1日だけ有効」という正当な設定として許可する
  def valid_date_range
    return if valid_from.blank? || valid_until.blank?

    if valid_until < valid_from
      errors.add(:valid_until, "は有効開始日以降の日付を指定してください")
    end
  end
end
