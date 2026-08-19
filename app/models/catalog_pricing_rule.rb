class CatalogPricingRule < ApplicationRecord
  include ValidPeriod

  belongs_to :target_catalog, class_name: "Catalog", foreign_key: "target_catalog_id"

  enum :price_kind,       { regular: 0, bundle: 1 },  validate: true
  enum :trigger_category, { bento: 0, side_menu: 1 }, validate: true, prefix: :triggered_by

  validates :price_kind,       presence: true
  validates :trigger_category, presence: true
  validates :max_per_trigger,  presence: true, numericality: { greater_than_or_equal_to: 0 }

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
