class Catalog < ApplicationRecord
  KANA_FORMAT = /\A[\p{Katakana}ー]*\z/

  # カートを描く経路が preload しておく関連
  #
  # price_by_kind と active_pricing_rules_at は、読み込み済みなら Ruby 側で選んで
  # SQL を撃たない。裏返すと、この 2 つを読まずにカートを組み立てると商品 1 種類ごとに
  # クエリが飛ぶ。片方だけ足しても抜けた方が N+1 のまま残るので、対で持つ
  PRICING_ASSOCIATIONS = %i[prices pricing_rules].freeze

  # 関連レコードが存在する場合は削除を禁止（DB レベルでも ON DELETE RESTRICT）
  has_one  :discontinuation, class_name: "CatalogDiscontinuation", dependent: :restrict_with_error
  has_many :prices, class_name: "CatalogPrice", dependent: :restrict_with_error
  has_many :pricing_rules, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id", dependent: :restrict_with_error
  has_many :active_pricing_rules, -> { active }, class_name: "CatalogPricingRule", foreign_key: "target_catalog_id"
  has_many :daily_inventories, dependent: :restrict_with_error
  has_many :sale_items, dependent: :restrict_with_error
  has_many :additional_orders, dependent: :restrict_with_error

  # 物理削除を禁止する
  # 背景: 商品カタログは販売履歴（SaleItem）から参照されるため、
  #       物理削除すると過去の販売データの整合性が失われる。
  #       提供終了する場合は CatalogDiscontinuation を作成して論理削除とする。
  before_destroy { throw :abort }

  # 販売可能な商品（提供終了記録がない）を取得
  scope :available, -> { where.missing(:discontinuation) }

  # 販売可能な商品に、その日の当日在庫がある商品を加えたもの
  #
  # 提供終了になっても当日在庫があればレジで売れる（販売画面は available で
  # 絞っていない）。売れる商品を在庫訂正の母集合から外すと、車に積んでいる数を
  # 直す手段が無いまま売れてしまうため、訂正では available より広いこちらを使う。
  scope :available_or_stocked_at, ->(location, date: Date.current) {
    where(id: Catalog.available.select(:id))
      .or(where(id: DailyInventory.where(location: location, inventory_date: date).select(:catalog_id)))
  }

  # 表示順序: 販売中を先、提供終了を後に表示（同じ状態内ではふりがな順）
  scope :display_order, -> {
    left_outer_joins(:discontinuation)
      .order(Arel.sql("catalog_discontinuations.id IS NOT NULL"))
      .order(:kana)
  }

  # 陳列カテゴリ。商品を画面上どう分けて並べるかの区分で、弁当とサラダの 2 つで閉じている。
  # enum の全値ではなくリテラルで持つ（ADR-0005）。Catalog.categories.keys から導くと、
  # 3 つ目の値が増えた瞬間に category_order の絞り込みが黙って広がる
  #
  # 差額精算の実行時ガード（Refunds::RefundForm#verify_displayable）はこの定数を読まない。
  # 読ませると、ここに値を足した瞬間にガードも一緒に外れ、タブを直す前に素通りしてしまう
  DISPLAY_CATEGORIES = %w[bento side_menu].freeze

  # カテゴリ順: 弁当 → サラダの順、同カテゴリ内はふりがな順。
  # in_order_of は既定で filter: true なので、陳列カテゴリ以外は WHERE で除外される
  scope :category_order, -> { in_order_of(:category, DISPLAY_CATEGORIES).order(:kana) }

  enum :category, { bento: 0, side_menu: 1 }, validate: true

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :category, presence: true
  validates :kana, presence: true,
                   format: { with: KANA_FORMAT,
                             message: "はカタカナで入力してください" }

  # 指定した種別の有効な価格を取得（存在しない場合は nil）
  #
  # prices が読み込み済みなら Ruby 側で選ぶ。preload しても毎回クエリが飛ぶと、
  # 商品カード 1 枚ごとに価格を引く販売画面で N+1 になるため
  #
  # @param kind [String, Symbol] 価格種別 ('regular' | 'bundle')
  # @param at [Time] 基準日時（デフォルト: 現在）
  # @return [CatalogPrice, nil]
  def price_by_kind(kind, at: Time.current)
    return CatalogPrice.pick_by_kind(prices, kind: kind, at: at) if prices.loaded?

    prices.price_by_kind(kind: kind, at: at)
  end

  # 指定した種別の価格が存在するか
  # @param kind [String, Symbol] 価格種別 ('regular' | 'bundle')
  # @param at [Time] 基準日時（デフォルト: 現在）
  # @return [Boolean]
  def price_exists?(kind, at: Time.current)
    price_by_kind(kind, at: at).present?
  end

  # 提供状態。status カラムは持たず、提供終了記録の有無から導出する
  def status
    discontinued? ? :discontinued : :available
  end

  # 提供終了かどうかを判定
  def discontinued?
    discontinuation.present?
  end

  # 指定した日付で有効な価格ルールを取得
  #
  # pricing_rules が読み込み済みなら Ruby 側で選ぶ。price_by_kind と同じ理由で、
  # preload しても毎回クエリが飛ぶと、カートの商品 1 種類ごとにルールを引く
  # 販売・返品の再描画で N+1 になるため
  #
  # 当日固定の active_pricing_rules 関連には寄せない。任意の基準日を受ける API なので、
  # POS の経路が実質いつも当日であることに暗黙に依存する形にはできない
  #
  # @param date [Date] 基準日（デフォルト: 今日）
  # @return [Array<CatalogPricingRule>]
  def active_pricing_rules_at(date = Date.current)
    return pricing_rules.select { |rule| rule.active_at?(date) } if pricing_rules.loaded?

    pricing_rules.active_at(date).to_a
  end
end
