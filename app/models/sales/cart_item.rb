# frozen_string_literal: true

# カートアイテム値オブジェクト
# DailyInventory と数量をラップし、販売画面で使用する
module Sales
  class CartItem
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_reader :inventory

    attribute :quantity, :integer, default: 0

    # @param inventory [DailyInventory] 日次在庫
    # @param attributes [Hash] ActiveModel::Attributes に渡す属性
    def initialize(inventory:, **attributes)
      @inventory = inventory
      super(**attributes)
    end

    delegate :catalog, to: :inventory

    def catalog_id
      catalog.id
    end

    def catalog_name
      catalog.name
    end

    def category
      catalog.category
    end

    def stock
      inventory.stock
    end

    def in_cart?
      quantity > 0
    end

    def bento?
      catalog.bento?
    end

    def side_menu?
      catalog.side_menu?
    end

    def sold_out?
      stock <= 0
    end

    def unit_price
      catalog.price_by_kind(:regular)&.price
    end
  end
end
