# frozen_string_literal: true

module DailyInventories
  class BulkCreator
    attr_reader :location, :inventory_params, :created_count, :error_message

    def initialize(location:, inventory_params:)
      @location = location
      @inventory_params = inventory_params
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
      return [] unless inventory_params[:inventories].present?

      inventory_params[:inventories].filter_map do |inv|
        next if inv[:stock].blank? || inv[:stock].to_i <= 0

        DailyInventory.new(
          location: location,
          catalog_id: inv[:catalog_id],
          inventory_date: Date.current,
          stock: inv[:stock].to_i,
          reserved_stock: 0
        )
      end
    end
  end
end
