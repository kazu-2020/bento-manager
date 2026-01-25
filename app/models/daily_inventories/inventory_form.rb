# frozen_string_literal: true

module DailyInventories
  class InventoryForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Rails.application.routes.url_helpers

    ITEM_TYPE = InventoryItemType.new

    attr_reader :items, :location

    def initialize(location:, catalogs:, state: {})
      @location = location
      @catalogs = catalogs
      @items = build_items(state)
    end

    def form_with_options
      { url: pos_location_daily_inventories_path(location), method: :post }
    end

    def form_state_options
      { url: pos_location_daily_inventories_form_state_path(location), method: :post }
    end

    def toggle(catalog_id)
      find_item(catalog_id)&.toggle
    end

    def update_stock(catalog_id, stock)
      find_item(catalog_id)&.update_stock(stock)
    end

    def increment(catalog_id)
      find_item(catalog_id)&.increment
    end

    def decrement(catalog_id)
      find_item(catalog_id)&.decrement
    end

    def selected_items
      @items.select(&:selected?)
    end

    def selected_count
      selected_items.count
    end

    def can_submit?
      selected_count.positive?
    end

    def to_state
      @items.each_with_object({}) do |item, hash|
        hash[item.catalog_id.to_s] = item.to_state_entry
      end
    end

    def to_inventory_params
      {
        inventories: selected_items.map(&:to_inventory_param)
      }
    end

    private

    def build_items(state)
      @catalogs.map do |catalog|
        saved = state[catalog.id.to_s] || {}
        ITEM_TYPE.cast(
          saved.symbolize_keys.merge(catalog_id: catalog.id, catalog_name: catalog.name)
        )
      end
    end

    def find_item(catalog_id)
      @items.find { |item| item.catalog_id == catalog_id.to_i }
    end
  end
end
