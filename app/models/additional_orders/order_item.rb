# frozen_string_literal: true

module AdditionalOrders
  class OrderItem
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :catalog_id, :integer
    attribute :catalog_name, :string
    attribute :available_stock, :integer, default: 0
    attribute :in_inventory, :boolean, default: false
    attribute :quantity, :integer, default: 0

    def in_inventory?
      in_inventory
    end

    def has_quantity?
      quantity > 0
    end
  end
end
