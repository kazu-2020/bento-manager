# frozen_string_literal: true

module Sales
  class CartItem
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_reader :inventory

    attribute :quantity, :integer, default: 0

    def initialize(inventory:, **attributes)
      @inventory = inventory
      super(**attributes)
    end

    delegate :catalog, :stock, to: :inventory
    delegate :id, :name, to: :catalog, prefix: :catalog
    delegate :category, :bento?, :side_menu?, to: :catalog

    def in_cart?
      quantity > 0
    end

    def sold_out?
      stock <= 0
    end

    def unit_price
      catalog.price_by_kind(:regular)&.price
    end
  end
end
