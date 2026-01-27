# frozen_string_literal: true

module Sales
  class CartItemType < ActiveModel::Type::Value
    private

    def cast_value(value)
      case value
      when CartItem then value
      when Hash     then CartItem.new(**value.symbolize_keys)
      end
    end
  end
end
