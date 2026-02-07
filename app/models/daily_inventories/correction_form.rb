# frozen_string_literal: true

module DailyInventories
  class CorrectionForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Rails.application.routes.url_helpers
    include ItemSelectable

    attr_reader :items, :location, :registered_count, :search_query

    validate :at_least_one_item_selected

    def initialize(location:, items:, search_query: nil)
      @location = location
      @search_query = search_query&.strip.presence
      @items = items
      @registered_count = 0
    end

    def save
      return false unless valid?

      result = DailyInventory.bulk_recreate(location: location, items: selected_items)

      if result == :sales_already_started
        errors.add(:base, :sales_already_started)
        return false
      end

      @registered_count = result

      if @registered_count.positive?
        true
      else
        errors.add(:base, :save_failed)
        false
      end
    end

    def form_with_options
      {
        url: pos_location_daily_inventories_correction_path(location),
        method: :post
      }
    end

    def form_state_options
      {
        url: pos_location_daily_inventories_corrections_form_state_path(location),
        method: :post
      }
    end

    private

    def at_least_one_item_selected
      errors.add(:base, :no_items_selected) unless selected_count.positive?
    end
  end
end
