# frozen_string_literal: true

module DailyInventories
  class InventoryForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    DEFAULT_STOCK = 10

    attr_reader :items

    def initialize(catalogs:, state: {})
      @catalogs = catalogs
      @items = build_items(state)
    end

    def toggle(catalog_id)
      item = find_item(catalog_id)
      return unless item

      item[:selected] = !item[:selected]
    end

    def update_stock(catalog_id, stock)
      item = find_item(catalog_id)
      return unless item

      item[:stock] = [[stock.to_i, 1].max, 999].min
    end

    def increment(catalog_id)
      item = find_item(catalog_id)
      return unless item
      return if item[:stock] >= 999

      item[:stock] += 1
    end

    def decrement(catalog_id)
      item = find_item(catalog_id)
      return unless item
      return if item[:stock] <= 1

      item[:stock] -= 1
    end

    def selected_items
      @items.select { |item| item[:selected] }
    end

    def selected_count
      selected_items.count
    end

    def can_submit?
      selected_count > 0
    end

    def to_state
      @items.each_with_object({}) do |item, hash|
        hash[item[:catalog_id].to_s] = {
          selected: item[:selected],
          stock: item[:stock]
        }
      end
    end

    def to_inventory_params
      {
        inventories: selected_items.map do |item|
          { catalog_id: item[:catalog_id], stock: item[:stock] }
        end
      }
    end

    private

    def build_items(state)
      @catalogs.map do |catalog|
        saved = state[catalog.id.to_s] || {}
        {
          catalog_id: catalog.id,
          catalog_name: catalog.name,
          selected: saved[:selected] || saved["selected"] || false,
          stock: saved[:stock] || saved["stock"] || DEFAULT_STOCK
        }
      end
    end

    def find_item(catalog_id)
      @items.find { |item| item[:catalog_id] == catalog_id.to_i }
    end
  end
end
