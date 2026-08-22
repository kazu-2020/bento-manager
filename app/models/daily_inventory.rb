class DailyInventory < ApplicationRecord
  class InsufficientStockError < StandardError; end

  belongs_to :location
  belongs_to :catalog

  validates :inventory_date, presence: true
  validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved_stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :inventory_date, uniqueness: {
    scope: [ :location_id, :catalog_id ],
    message: "同じ販売先・商品・日付の組み合わせは既に存在します"
  }

  validate :available_stock_must_be_non_negative

  # 弁当の在庫行だけに絞る。数えるのは弁当だけという業務境界は Sale 側と同じもので、
  # 弁当販売履歴の消化率は分母をこのスコープで、分子を Sale.joining_bento_items で取る
  # （ADR-0005 / ADR-0006）
  scope :bento, -> { joins(:catalog).merge(Catalog.bento) }

  # POS のカート（販売・差額精算）が並べる在庫。商品カードは 1 件ごとに単価と
  # 価格ルールを引くため、catalog に PRICING_ASSOCIATIONS を載せておかないと
  # 並ぶ商品の数だけ問い合わせが増える。数量を動かすたびに Ghost Form が
  # 再描画される画面なので、その本数が操作のたびにまるごと乗る
  scope :for_cart, -> {
    eager_load(:catalog)
      .preload(catalog: Catalog::PRICING_ASSOCIATIONS)
      .merge(Catalog.category_order)
  }

  # 販売先・商品・日付に対応する在庫を取得する
  #
  # 在庫が見つからないときの扱いは在庫の関心事であって、記録・返金処理の関心事では
  # ない。集約したので変えるときはここだけを触る。現状は find_by! の RecordNotFound
  # を素通ししており、専用の例外に替えて POS の画面に返す話は #373 で扱う。
  #
  # 呼び出し側が ID を渡すのは関連の読み込みを避けるため（sale_item.catalog を経由
  # すると明細ごとに 1 クエリ増える）。where は関連名キーに ID を渡しても解決する
  #
  # @param location [Location, Integer] 販売先（レコードまたは ID）
  # @param catalog [Catalog, Integer] 商品（レコードまたは ID）
  # @param date [Date] 在庫日
  # @raise [ActiveRecord::RecordNotFound] 一致する在庫がない場合
  def self.find_for!(location:, catalog:, date:)
    find_by!(location: location, catalog: catalog, inventory_date: date)
  end

  def self.bulk_recreate(location:, items:)
    transaction do
      return :sales_already_started if Sale.started?(location: location)

      delete_by(location: location, inventory_date: Date.current)
      bulk_create(location: location, items: items)
    end
  end

  def self.bulk_create(location:, items:)
    inventories = items.map do |item|
      new(
        location: location,
        catalog_id: item.catalog_id,
        inventory_date: Date.current,
        stock: item.stock,
        reserved_stock: 0
      )
    end

    result = transaction do
      inventories.each do |inventory|
        inventory.save || raise(ActiveRecord::Rollback)
      end
    end

    result.nil? ? 0 : inventories.size
  end

  # 利用可能在庫数を計算
  def available_stock
    stock - reserved_stock
  end

  # 在庫減算（販売時）
  #
  # 増減は必ず with_lock を通すこと（increment_stock! も同じ）。トランザクション
  # 内で reload するため lock_version が常に最新に揃う。「SQLite では行ロックに
  # ならないから」と外すと、楽観ロックが競合して StaleObjectError が POS 画面の
  # 500 として表に出る。理由は docs/adr/0003-sqlite-concurrency-control.md を参照。
  #
  # @param quantity [Integer] 減算する数量（正の整数）
  # @raise [ArgumentError] 数量が正の整数でない場合
  # @raise [InsufficientStockError] 在庫不足の場合
  def decrement_stock!(quantity)
    validate_positive_quantity!(quantity)

    with_lock do
      if stock < quantity
        raise InsufficientStockError, "在庫が不足しています（現在: #{stock}, 必要: #{quantity}）"
      end

      self.stock -= quantity
      save!
    end
  end

  # 在庫加算（差額精算での在庫復元時、追加発注時）
  #
  # with_lock の扱いは decrement_stock! の説明を参照
  #
  # @param quantity [Integer] 加算する数量（正の整数）
  # @raise [ArgumentError] 数量が正の整数でない場合
  def increment_stock!(quantity)
    validate_positive_quantity!(quantity)

    with_lock do
      self.stock += quantity
      save!
    end
  end

  private

  # 利用可能在庫数が0以上であることを検証
  def available_stock_must_be_non_negative
    return if stock.blank? || reserved_stock.blank?

    if available_stock < 0
      errors.add(:base, "利用可能在庫数（stock - reserved_stock）は0以上である必要があります")
    end
  end

  # 数量が正の整数であることを検証
  def validate_positive_quantity!(quantity)
    unless quantity.is_a?(Integer) && quantity.positive?
      raise ArgumentError, "数量は正の整数である必要があります"
    end
  end
end
