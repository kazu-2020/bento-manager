class Discount < ApplicationRecord
  include ValidPeriod

  has_many :sale_discounts, dependent: :restrict_with_exception
  has_many :sales, through: :sale_discounts

  delegated_type :discountable, types: %w[Coupon], autosave: true
  delegate :applicable?, :max_applicable_quantity, to: :discountable

  validates :name, presence: true

  # 割引を読むときは、たいてい discountable（Coupon）まで要る。1 枚あたりの割引額も
  # 適用可否もそちらが持っているためで、名前だけ出す画面は無い。ポリモーフィックな
  # belongs_to は eager_load できないので preload を使う（.claude/rules/eager_loading.md）
  scope :with_discountable, -> { preload(:discountable) }

  # 画面に並べる割引の母集合。日付の絞り込みは当日固定なので、別の日を基準にする
  # 集計や再計算はこれを使わず active_at を自分で書くこと。
  #
  # relation を返すので、ロード済みかどうかは渡す側の責任。未ロードのまま any? に当たると
  # 存在確認だけの問い合わせが 1 本乗るので、画面に渡す前にロードまで済ませること。
  # 調達の経路は画面ごとに違ってよい（販売は 2 つのコントローラーが共有するので注入、
  # 差額精算はフォーム内部で完結する）
  scope :active_with_discountable, -> { with_discountable.active }

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
end
