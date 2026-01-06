class CatalogPricingRule < ApplicationRecord
  belongs_to :target_catalog, class_name: "Catalog", foreign_key: "target_catalog_id"

  enum :price_kind, { regular: 0, bundle: 1 }, validate: true

  validates :price_kind, presence: true
  validates :trigger_category, presence: true
  validates :max_per_trigger, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :valid_from, presence: true
  validate :valid_date_range

  scope :active, -> {
    where(valid_from: ..Date.current)
      .merge(
        where(valid_until: nil).or(where(valid_until: Date.current..))
      )
  }
  scope :for_target, ->(catalog_id) { where(target_catalog_id: catalog_id) }
  scope :triggered_by, ->(category) { where(trigger_category: category) }

  # カート内に trigger_category があるかどうかを判定
  def applicable?(cart_items)
    trigger_count = count_trigger_items(cart_items)
    trigger_count > 0
  end

  # ルールを適用できる最大数量を計算
  def max_applicable_quantity(cart_items)
    trigger_count = count_trigger_items(cart_items)
    trigger_count * max_per_trigger
  end

  private

  # valid_until が valid_from より後であることを検証
  def valid_date_range
    return if valid_from.blank? || valid_until.blank?

    if valid_until <= valid_from
      errors.add(:valid_until, "は有効開始日より後の日付を指定してください")
    end
  end

  def count_trigger_items(cart_items)
    cart_items.sum do |item|
      if item[:catalog].category == trigger_category
        item[:quantity]
      else
        0
      end
    end
  end
end
