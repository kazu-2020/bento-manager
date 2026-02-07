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

  def self.sales_started?(location:, date: Date.current)
    where(location: location, inventory_date: date)
      .where("lock_version > 0")
      .exists?
  end

  def self.bulk_recreate(location:, items:)
    transaction do
      return :sales_already_started if sales_started?(location: location)

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

  # Task 6.4: 在庫減算（販売時）
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

  # Task 6.4: 在庫加算（返品時、追加発注時）
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
