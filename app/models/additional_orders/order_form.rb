# frozen_string_literal: true

module AdditionalOrders
  class OrderForm
    include ActiveModel::Model
    include Rails.application.routes.url_helpers

    attr_reader :items, :location, :created_count, :search_query

    validate :at_least_one_item_has_quantity

    def initialize(location:, catalogs:, stock_map: {}, search_query: nil, submitted: {})
      @location = location
      @catalogs = catalogs
      @stock_map = stock_map
      @search_query = search_query&.strip.presence
      @items = build_items(submitted)
      @created_count = 0
    end

    def save(employee:)
      return false unless valid?

      ordered_items = items_with_quantity

      ActiveRecord::Base.transaction do
        ordered_items.each do |item|
          AdditionalOrder.create_with_inventory!(
            location: location,
            catalog_id: item.catalog_id,
            employee: employee,
            quantity: item.quantity,
            order_at: Time.current
          )
        end
      end

      @created_count = ordered_items.size
      true
    rescue ActiveRecord::RecordInvalid => e
      errors.add(:base, e.record.errors.full_messages.first)
      false
    end

    def form_with_options
      { url: pos_location_additional_orders_path(location), method: :post }
    end

    def form_state_options
      { url: pos_location_additional_orders_form_state_path(location), method: :post }
    end

    def items_with_quantity
      items.select(&:has_quantity?)
    end

    def total_available_stock
      items.sum(&:available_stock)
    end

    def visible?(item)
      return true if search_query.blank?

      item.catalog_name.include?(search_query)
    end

    def inventory_items
      @inventory_items ||= items.select(&:in_inventory?)
    end

    def non_inventory_items
      @non_inventory_items ||= items.reject(&:in_inventory?)
    end

    private

    def at_least_one_item_has_quantity
      errors.add(:base, :no_items_ordered) unless items_with_quantity.any?
    end

    def build_items(submitted)
      @catalogs.map do |catalog|
        saved = submitted[catalog.id.to_s] || {}
        AdditionalOrders::OrderItem.new(
          catalog_id: catalog.id,
          catalog_name: catalog.name,
          available_stock: @stock_map[catalog.id] || 0,
          in_inventory: @stock_map.key?(catalog.id),
          quantity: saved[:quantity].to_i
        )
      end
    end
  end
end
