# frozen_string_literal: true

module AdditionalOrders
  class OrderForm
    include ActiveModel::Model
    include Rails.application.routes.url_helpers

    attr_reader :items, :location, :created_count

    validate :at_least_one_item_has_quantity

    def initialize(location:, inventories:, submitted: {})
      @location = location
      @inventories = inventories
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

    def items_with_quantity
      items.select(&:has_quantity?)
    end

    def total_available_stock
      items.sum(&:available_stock)
    end

    private

    def at_least_one_item_has_quantity
      errors.add(:base, :no_items_ordered) unless items_with_quantity.any?
    end

    def build_items(submitted)
      @inventories.map do |inventory|
        saved = submitted[inventory.catalog_id.to_s] || {}
        AdditionalOrders::OrderItem.new(
          catalog_id: inventory.catalog_id,
          catalog_name: inventory.catalog.name,
          available_stock: inventory.available_stock,
          quantity: saved[:quantity].to_i
        )
      end
    end
  end
end
