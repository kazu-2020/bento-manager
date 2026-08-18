class CatalogPrice < ApplicationRecord
  belongs_to :catalog
  has_many   :sale_items, dependent: :restrict_with_error

  enum :kind, { regular: 0, bundle: 1 }, validate: true

  validates :kind,           presence: true
  validates :price,          presence: true, numericality: { greater_than: 0 }
  validates :effective_from, presence: true

  validate :valid_date_range

  scope :effective_at, ->(at) {
    at = boundary_time(at)

    where(effective_from: ..at)
      .merge(
        where(effective_until: nil).or(where(effective_until: at..))
      )
  }
  scope :current, -> { effective_at(Time.current) }
  scope :by_kind, ->(kind) { where(kind: kind) }

  def self.price_by_kind(kind:, at: Time.current)
    by_kind(kind).effective_at(at).order(effective_from: :desc).first
  end

  # 読み込み済みの価格から price_by_kind と同じ 1 件を選ぶ
  #
  # preload した prices に対して price_by_kind を呼ぶと関連が読み込み済みでも毎回
  # クエリが飛ぶため、Ruby 側で同じ選択を行う入口を用意する。SQL 版と選択結果が
  # ずれないよう、絞り込みは effective_at? に、優先順位は effective_from の降順に
  # 揃えてある。
  #
  # @param prices [Enumerable<CatalogPrice>] 読み込み済みの価格
  # @param kind [String, Symbol, Integer] 価格種別
  # @param at [Time, Date] 基準日時
  # @return [CatalogPrice, nil]
  def self.pick_by_kind(prices, kind:, at: Time.current)
    # where(kind:) は整数・シンボル・文字列のどれでも引ける。属性と同じ文字列に
    # 揃えるのは enum の型自身の仕事なので、対応表を持たずに cast へ委ねる
    kind = type_for_attribute(:kind).cast(kind)

    prices.select { |price| price.kind == kind && price.effective_at?(at) }
          .max_by(&:effective_from)
  end

  # 指定日時に有効な価格か（effective_at スコープの Ruby 版、両端 inclusive）
  #
  # @param at [Time, Date] 基準日時
  # @return [Boolean]
  def effective_at?(at)
    # effective_until が nil なら終端なしの Range になり、開始端だけで判定される
    (effective_from..effective_until).cover?(self.class.boundary_time(at))
  end

  # 有効期間の境界に使う日時を決める
  #
  # Date をそのまま where に渡すと 'YYYY-MM-DD' として引用され、UTC で保存された
  # datetime 文字列との文字列比較になる。両端の inclusive/exclusive が食い違ううえ、
  # Ruby 側で同じ比較を書き起こせない。SQL と Ruby の 2 経路が同じ答えを返すために、
  # 日付は SQL に渡す前に UTC 0 時へ寄せる（従来の文字列比較の境界と同じ位置）。
  #
  # DateTime は Date のサブクラスだが時刻を持ち、where でも完全な日時として引用される
  # ため触らない（instance_of? で日付だけを拾う）。
  #
  # @param at [Time, Date]
  # @return [Time, Date]
  def self.boundary_time(at)
    at.instance_of?(Date) ? at.to_time(:utc) : at
  end

  # 新しい価格を作成し、既存の有効な価格があれば終了させる
  # @param catalog [Catalog] 対象カタログ
  # @param kind [String, Symbol] 価格種別
  # @param price [Integer] 新しい価格
  # @return [CatalogPrice] 作成された新しい価格レコード
  # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
  def self.create_with_history!(catalog:, kind:, price:)
    current_price = catalog.price_by_kind(kind)
    new_price = new(catalog: catalog, kind: kind, price: price, effective_from: Time.current)

    transaction do
      current_price&.update!(effective_until: Time.current)
      new_price.save!
    end

    new_price
  end

  private

  # effective_until が effective_from より後であることを検証
  # effective_at も両端 inclusive なので同時刻のレコードはヒットする。それでも同時刻を
  # 認めないのは、datetime の同一インスタンスが date の「1日」と違い、ユーザーが意図して
  # 指定する有効期間の単位ではないため
  def valid_date_range
    return if effective_from.blank? || effective_until.blank?

    if effective_until <= effective_from
      errors.add(:effective_until, "は適用開始日時より後の日時を指定してください")
    end
  end
end
