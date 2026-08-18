# frozen_string_literal: true

module Refunds
  # 修正カートの 1 行。元の販売の商品と、当日在庫にある未購入の商品の両方がここに並ぶ
  class CorrectedItem
    attr_reader :catalog, :quantity, :original_quantity, :max_quantity, :inventory

    delegate :id, :name, to: :catalog, prefix: :catalog
    delegate :category, :bento?, :side_menu?, to: :catalog

    def initialize(catalog:, quantity:, original_quantity:, max_quantity:, inventory: nil)
      @catalog = catalog
      @quantity = quantity
      @original_quantity = original_quantity
      @max_quantity = max_quantity
      @inventory = inventory
    end

    def changed?
      quantity != original_quantity
    end

    def in_cart?
      quantity > 0
    end

    def unit_price
      catalog.price_by_kind(:regular)&.price
    end

    # 数量を選びようがない状態。元の販売に含まれず、当日在庫も無い商品が該当する。
    # 当日在庫が 0 でも元の販売に含まれていれば返品で戻るので、売り切れとは別物
    def unavailable?
      max_quantity <= 0
    end
  end
end
