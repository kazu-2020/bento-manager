# 有効期間（valid_from / valid_until）を持つレコードの共通処理
#
# 期間は date で持ち、開始端・終端とも inclusive に扱う。終端が nil なら無期限。
# datetime で期間を持つ CatalogPrice は境界の寄せ方（boundary_time）が別物のため
# ここには含めない。
module ValidPeriod
  extend ActiveSupport::Concern

  included do
    # 指定日時点で有効なレコードを取得
    scope :active_at, ->(date) {
      where(valid_from: ..date)
        .merge(
          where(valid_until: nil).or(where(valid_until: date..))
        )
    }
    scope :active, -> { active_at(Date.current) }

    validates :valid_from, presence: true

    validate :valid_date_range
  end

  # 指定日に有効か（active_at スコープの Ruby 版、両端 inclusive）
  #
  # @param date [Date] 基準日
  # @return [Boolean]
  def active_at?(date)
    # valid_from が無いうちは、いつの時点でも有効ではない。ここを Range に任せると
    # (nil..nil) が全ての日付を cover? してしまう
    return false if valid_from.nil?

    # valid_until が nil なら終端なしの Range になり、開始端だけで判定される
    (valid_from..valid_until).cover?(date)
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
