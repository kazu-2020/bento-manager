# frozen_string_literal: true

module DailyInventories
  class InventoryItem
    include ActiveModel::Model
    include ActiveModel::Attributes

    DEFAULT_STOCK = 10
    MIN_STOCK = 1
    MAX_STOCK = 999

    attribute :catalog_id, :integer
    attribute :catalog_name, :string
    attribute :selected, :boolean, default: false
    attribute :stock, :integer, default: DEFAULT_STOCK

    def selected?
      !!selected
    end

    def toggle
      self.selected = !selected
    end

    def update_stock(value)
      self.stock = [ [ value.to_i, MIN_STOCK ].max, MAX_STOCK ].min
    end

    def to_inventory_param
      { catalog_id: catalog_id, stock: stock }
    end
  end
end
