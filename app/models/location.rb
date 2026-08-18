class Location < ApplicationRecord
  has_many :daily_inventories, dependent: :restrict_with_error
  has_many :today_inventories,
           -> { where(inventory_date: Date.current) },
           class_name: "DailyInventory"
  has_many :sales, dependent: :restrict_with_error
  has_many :additional_orders, dependent: :restrict_with_error

  enum :status, { active: 0, inactive: 1 }, validate: true

  scope :display_order, -> { in_order_of(:status, %w[active inactive]).order(:name) }

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def has_today_inventory?
    today_inventories.any?
  end

  def sales_started_today?
    Sale.started?(location: self)
  end

  # 当日の追加発注の商品別合計
  #
  # 在庫訂正フォームが並べる商品と母集合を揃えるため、販売可能な商品に絞る。
  #
  # @return [Hash{Catalog => Integer}] 商品ごとの追加発注個数（表示順）
  def today_additional_order_quantities
    quantities = additional_orders
                   .where(order_at: Date.current.all_day)
                   .group(:catalog_id)
                   .sum(:quantity)

    return {} if quantities.empty?

    Catalog.available
           .where(id: quantities.keys)
           .category_order
           .index_with { |catalog| quantities[catalog.id] }
  end

  def daily_sales_quantity(period: 1.month)
    date_expr = Arel.sql(
      self.class.sanitize_sql_array([ "DATE(sale_datetime, ?)", Time.zone.now.formatted_offset ])
    )

    sales
      .completed
      .where(sale_datetime: period.ago.beginning_of_day..)
      .joins(:items)
      .group(date_expr, :customer_type)
      .sum("sale_items.quantity")
  end
end
