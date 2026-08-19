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
  # idx_catalog_prices_open_ended_unique と同じ述語。商品・種別ごとに高々 1 件
  scope :open_ended, -> { where(effective_until: nil) }

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
    # 旧価格の終了と新価格の開始に同じ時刻を使う。Time.current を評価し直すと
    # その差分だけ両方が有効な期間ができる（両端 inclusive なので切替の一点では
    # 依然どちらも有効で、勝者は price_by_kind の effective_from 降順が決める）
    now = Time.current

    # 閉じる相手は effective_at ではなく open_ended で選ぶ。一意制約が見ているのが
    # 「終了していない価格」なので、述語がずれると閉じ損ねた行が残って insert が弾かれる。
    # 例えば effective_until を未来に持つ行が間に挟まると、effective_at はそちらを
    # 現在価格として返し、本当に終了していない古い行は開いたまま残る
    current_price = catalog.prices.open_ended.by_kind(kind).first

    # 同じ時刻に始まった価格は有効だった期間が無い。終了時刻を入れると
    # valid_date_range（effective_until <= effective_from を弾く）に掛かるので、
    # 履歴を積まずに金額だけ差し替える。freeze_time 下の連続更新がこれに当たる
    if current_price && current_price.effective_from >= now
      current_price.update!(price: price)
      return current_price
    end

    new_price = new(catalog: catalog, kind: kind, price: price, effective_from: now)

    transaction do
      # 旧価格を先に終了させる。順序を入れ替えると終了していない価格が一瞬 2 件になり、
      # 一意制約に弾かれる
      current_price&.update!(effective_until: now)
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
