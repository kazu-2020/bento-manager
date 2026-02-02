# frozen_string_literal: true

module DailyInventories
  class InventoryForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Rails.application.routes.url_helpers

    ITEM_TYPE = InventoryItemType.new

    attr_reader :items, :location, :created_count, :search_query

    validate :at_least_one_item_selected

    def initialize(location:, catalogs:, submitted: {}, search_query: nil)
      @location = location
      @catalogs = catalogs
      @search_query = search_query&.strip.presence
      @items = build_items(submitted)
      @created_count = 0
    end

    def visible?(item)
      return true if @search_query.blank?

      item.catalog_name.include?(@search_query)
    end

    def save
      return false unless valid?

      @created_count = DailyInventory.bulk_create(location: location, items: selected_items)
      return true if @created_count.positive?

      errors.add(:base, :save_failed)
      false
    end

    def form_with_options
      {
        url: pos_location_daily_inventories_path(location),
        method: :post
      }
    end

    def form_state_options
      {
        url: pos_location_daily_inventories_form_state_path(location),
        method: :post
      }
    end

    def selected_items
      @items.select(&:selected?)
    end

    def selected_count
      selected_items.count
    end

    def bento_items
      @items.select { |item| item.category == "bento" }
    end

    def side_menu_items
      @items.select { |item| item.category == "side_menu" }
    end

    private

    def at_least_one_item_selected
      errors.add(:base, :no_items_selected) unless selected_count.positive?
    end

    def build_items(submitted)
      @catalogs.map do |catalog|
        saved = submitted[catalog.id.to_s] || {}
        ITEM_TYPE.cast(
          saved.symbolize_keys.merge(catalog_id: catalog.id, catalog_name: catalog.name, category: catalog.category)
        )
      end
    end
  end
end
