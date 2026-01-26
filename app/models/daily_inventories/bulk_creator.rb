# frozen_string_literal: true

module DailyInventories
  class BulkCreator
    attr_reader :location, :items, :created_count, :error_message

    def initialize(location:, items:)
      @location = location
      @items = items
      @created_count = 0
      @error_message = nil
    end

    def call
      inventories = build_inventories
      return false if inventories.empty?

      ActiveRecord::Base.transaction do
        inventories.each do |inventory|
          unless inventory.save
            @error_message = inventory.errors.full_messages.join(", ")
            raise ActiveRecord::Rollback
          end
          @created_count += 1
        end
      end

      @error_message.nil?
    end

    private

    def build_inventories
      return [] unless items.present?

      items.filter_map do |item|
        next if item.stock <= 0

        DailyInventory.new(
          location: location,
          catalog_id: item.catalog_id,
          inventory_date: Date.current,
          stock: item.stock,
          reserved_stock: 0
        )
      end
    end
  end
end
