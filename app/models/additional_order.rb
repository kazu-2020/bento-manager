class AdditionalOrder < ApplicationRecord
  belongs_to :location
  belongs_to :catalog
  belongs_to :employee, optional: true

  scope :ordered_on, ->(date) { where(order_at: date.all_day) }

  validates :order_at, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }

  # 指定日の追加発注を商品別に合計する
  #
  # @param location [Location] 販売先
  # @param date [Date] 集計対象の日付
  # @param since [Time, nil] 指定するとこの時刻以降の発注だけを数える
  # @return [Hash{Integer => Integer}] 商品 ID ごとの追加発注個数
  def self.quantities_by_catalog_id(location:, date: Date.current, since: nil)
    scope = where(location: location).ordered_on(date)
    scope = scope.where(order_at: since..) if since

    scope.group(:catalog_id).sum(:quantity)
  end

  # 追加発注を作成し、在庫を加算する
  #
  # @param attributes [Hash] AdditionalOrder の属性
  # @return [AdditionalOrder] 作成された追加発注レコード
  # @raise [ActiveRecord::RecordInvalid] バリデーション失敗時
  def self.create_with_inventory!(attributes)
    transaction do
      order = create!(attributes)

      inventory = DailyInventory.find_or_create_by!(
        location: order.location,
        catalog: order.catalog,
        inventory_date: order.order_at.to_date
      )

      inventory.increment_stock!(order.quantity)
      order
    end
  end
end
