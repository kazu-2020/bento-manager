# frozen_string_literal: true

module DailyInventories
  class InventoryItemType < ActiveModel::Type::Value
    private

    def cast_value(value)
      case value
      when InventoryItem
        value
      when Hash
        InventoryItem.new(value)
      end
    end
  end
end
