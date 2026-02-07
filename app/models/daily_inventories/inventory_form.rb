# frozen_string_literal: true

module DailyInventories
  class InventoryForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Rails.application.routes.url_helpers
    include ItemSelectable

    attr_reader :items, :location, :created_count, :search_query

    validate :at_least_one_item_selected

    def initialize(location:, items:, search_query: nil)
      @location = location
      @search_query = search_query&.strip.presence
      @items = items
      @created_count = 0
    end

    def save
      return false unless valid?

      @created_count = DailyInventory.bulk_create(location: location, items: selected_items)

      if @created_count.positive?
        true
      else
        errors.add(:base, :save_failed)
        false
      end
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

    private

    def at_least_one_item_selected
      errors.add(:base, :no_items_selected) unless selected_count.positive?
    end
  end
end
