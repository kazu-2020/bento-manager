# frozen_string_literal: true

module Sales
  class CartForm
    include ActiveModel::Model
    include Rails.application.routes.url_helpers

    ITEM_TYPE = CartItemType.new

    attr_reader :location, :items, :discounts, :customer_type

    validate :at_least_one_item_in_cart
    validates :customer_type, presence: true

    def initialize(location:, inventories:, discounts:, submitted: {})
      @location = location
      @discounts = discounts
      @items = build_items(inventories, submitted)
      @customer_type = submitted["customer_type"] || "citizen"
      @coupon_quantities = build_coupon_quantities(submitted)
    end

    def bento_items
      items.select(&:bento?)
    end

    def side_menu_items
      items.select(&:side_menu?)
    end

    def cart_items
      items.select(&:in_cart?)
    end

    def cart_items_for_calculator
      cart_items.map { |item| { catalog: item.catalog, quantity: item.quantity } }
    end

    def selected_discount_ids
      discount_quantities_for_calculator.keys
    end

    def discount_quantities_for_calculator
      @coupon_quantities.select { |_, qty| qty > 0 }
    end

    def coupon_quantity(discount)
      @coupon_quantities[discount.id] || 0
    end

    def price_result
      @price_result ||= calculate_prices
    end

    def has_items_in_cart?
      items.any?(&:in_cart?)
    end

    def total_bento_quantity
      bento_items.select(&:in_cart?).sum(&:quantity)
    end

    def form_with_options
      { url: pos_location_sales_path(location), method: :post }
    end

    def form_state_options
      { url: pos_location_sales_form_state_path(location), method: :post }
    end

    private

    def build_items(inventories, submitted)
      inventories.map do |inventory|
        qty = submitted.dig(inventory.catalog_id.to_s, "quantity") || 0
        ITEM_TYPE.cast(inventory: inventory, quantity: qty)
      end
    end

    def at_least_one_item_in_cart
      errors.add(:base, :no_items_in_cart) unless has_items_in_cart?
    end

    def build_coupon_quantities(submitted)
      coupon_data = submitted["coupon"] || {}
      coupon_data.to_h.transform_keys(&:to_i).transform_values { |v| v["quantity"].to_i }
    end

    def calculate_prices
      calculator = Sales::PriceCalculator.new(
        cart_items_for_calculator,
        discount_quantities: discount_quantities_for_calculator
      )
      calculator.calculate
    rescue Errors::MissingPriceError
      PriceCalculator.new([]).calculate
    end
  end
end
