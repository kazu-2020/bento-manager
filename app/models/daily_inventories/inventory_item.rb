# frozen_string_literal: true

module DailyInventories
  class InventoryItem
    include ActiveModel::Model
    include ActiveModel::Attributes

    DEFAULT_STOCK = 10

    attribute :catalog_id, :integer
    attribute :catalog_name, :string
    attribute :selected, :boolean, default: false
    attribute :stock, :integer, default: DEFAULT_STOCK

    def selected?
      !!selected
    end
  end
end
