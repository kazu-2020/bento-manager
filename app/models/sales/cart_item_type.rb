# frozen_string_literal: true

module Sales
  class CartItemType < ActiveModel::Type::Value
    private

    def cast_value(value)
      case value
      when CartItem
        value
      when Hash
        CartItem.new(**value.symbolize_keys)
      end
    end
  end
end
