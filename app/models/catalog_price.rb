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

  # 同じ effective_from が並んだときの勝者を id で決める。第 2 ソートキーが無いと
  # SQLite の走査順まかせになり、Ruby 側（pick_by_kind）と答えが割れうる
  def self.price_by_kind(kind:, at: Time.current)
    by_kind(kind).effective_at(at).order(effective_from: :desc, id: :desc).first
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

    # persisted? で未保存を落とす。読み込み済みの target には prices.build した行も
    # 並ぶ（CatalogPricesController#edit や Catalogs::BaseCreator がそうする）が、
    # SQL 版はそれを見ようがないので、拾うと preload の有無で答えが割れる
    prices.select { |price| price.persisted? && price.kind == kind && price.effective_at?(at) }
          .max_by { |price| [ price.effective_from, price.id ] }
  end

  # 指定日時に有効な価格か（effective_at スコープの Ruby 版、両端 inclusive）
  #
  # @param at [Time, Date] 基準日時
  # @return [Boolean]
  def effective_at?(at)
    # effective_from が無いうちは、いつの時点でも有効ではない。ここを Range に任せると
    # (nil..nil) が全ての時刻を cover? してしまう
    return false if effective_from.nil?

    # effective_until が nil なら終端なしの Range になり、開始端だけで判定される
    (effective_from..effective_until).cover?(self.class.boundary_time(at))
  end

  # 有効期間の境界に使う日時を決める
  #
  # Date をそのまま where に渡すと 'YYYY-MM-DD' として引用され、UTC で保存された
  # datetime 文字列との文字列比較になる。この比較は開始端だけが exclusive になる
  # （'2026-08-18 00:00:00.000000' は前方一致で長い分だけ大きく、'2026-08-18' 以下に
  # ならない）。Ruby 側では書き起こせない非対称なので、日付は SQL に渡す前に UTC 0 時の
  # Time へ寄せ、両端 inclusive の素直な日時比較に揃える。
  #
  # 境界の位置は変わらないが、UTC 0 時ちょうどに始まる価格の扱いだけは変わる。従来は
  # その日から有効にならなかったものが、有効になる。Date を渡すのは
  # Catalogs::PriceValidator 経由の呼び出し元（PricingRuleCreator#price_exists? など）。
  #
  # なお UTC 0 時（JST の 9 時）という境界そのものは、この文字列比較の副作用が
  # そのまま残ったもの。JST の 0 時に直すかは価格の有効性が動く話なので別で扱う。
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
