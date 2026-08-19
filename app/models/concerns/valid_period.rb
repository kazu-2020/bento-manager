# 有効期間（valid_from / valid_until）を持つレコードの共通処理
#
# 期間は date で持ち、開始端・終端とも inclusive に扱う。終端が nil なら無期限。
# 同日指定は「その 1 日だけ有効」という正当な設定として許可する。CatalogPrice が
# 同時刻を弾くのとは非対称だが、これは仕様（理由は CatalogPrice#valid_date_range）。
#
# その CatalogPrice は期間を datetime で持ち、境界の寄せ方（boundary_time）が別物の
# ためここには含めない。ただし ADR-0004 決定 3 のとおり型の選択自体が未決で、#358 で
# date に寄せる可能性が残っている。寄せたときはこの concern が受け皿になる。
module ValidPeriod
  extend ActiveSupport::Concern

  included do
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

  # 指定日に有効か（active_at スコープの Ruby 版）
  #
  # @param date [Date] 基準日
  # @return [Boolean]
  def active_at?(date)
    # ここを Range に任せると (nil..nil) が全ての日付を cover? してしまう
    return false if valid_from.nil?

    (valid_from..valid_until).cover?(date)
  end

  private

  def valid_date_range
    return if valid_from.blank? || valid_until.blank?

    if valid_until < valid_from
      errors.add(:valid_until, "は有効開始日以降の日付を指定してください")
    end
  end
end
