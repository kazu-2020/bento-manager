# frozen_string_literal: true

module AdditionalOrders
  class OrderItem
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :catalog_id, :integer
    attribute :catalog_name, :string
    attribute :available_stock, :integer, default: 0
    attribute :quantity, :integer, default: 0

    def has_quantity?
      quantity > 0
    end
  end
end
