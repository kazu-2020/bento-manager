# frozen_string_literal: true

module DailyInventories
  class InventoryForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Rails.application.routes.url_helpers

    ITEM_TYPE = InventoryItemType.new

    attr_reader :items, :location

    def initialize(location:, catalogs:, submitted: {})
      @location = location
      @catalogs = catalogs
      @items = build_items(submitted)
    end

    def form_with_options
      { url: pos_location_daily_inventories_path(location), method: :post }
    end

    def form_state_options
      { url: pos_location_daily_inventories_form_state_path(location), method: :post }
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

    def to_inventory_params
      {
        inventories: selected_items.map(&:to_inventory_param)
      }
    end

    private

    def build_items(submitted)
      @catalogs.map do |catalog|
        saved = submitted[catalog.id.to_s] || {}
        ITEM_TYPE.cast(
          saved.symbolize_keys.merge(catalog_id: catalog.id, catalog_name: catalog.name)
        )
      end
    end
  end
end
