# frozen_string_literal: true

# カート状態管理フォームオブジェクト
# DailyInventories::InventoryForm と同パターンで販売画面のフォーム状態を管理する
module Sales
  class CartForm
    include ActiveModel::Model
    include Rails.application.routes.url_helpers

    ITEM_TYPE = CartItemType.new

    attr_reader :location, :items, :discounts, :customer_type

    validate :at_least_one_item_in_cart
    validate :customer_type_present

    # @param location [Location] 販売先
    # @param inventories [Array<DailyInventory>] 本日の在庫一覧
    # @param discounts [Array<Discount>] 有効な割引一覧
    # @param submitted [Hash] フォーム送信値
    def initialize(location:, inventories:, discounts:, submitted: {})
      @location = location
      @discounts = discounts
      @items = build_items(inventories, submitted)
      @customer_type = submitted["customer_type"]
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

    # PriceCalculator 用のカートアイテム配列を生成
    # @return [Array<Hash>] [{ catalog: Catalog, quantity: Integer }, ...]
    def cart_items_for_calculator
      cart_items.map { |item| { catalog: item.catalog, quantity: item.quantity } }
    end

    # 選択されたクーポンの ID 配列
    def selected_discount_ids
      @coupon_quantities.select { |_, qty| qty > 0 }.keys
    end

    # PriceCalculator / Recorder 用の割引枚数 Hash を生成
    # @return [Hash{Integer => Integer}] { discount_id => 枚数 }
    def discount_quantities_for_calculator
      @coupon_quantities.select { |_, qty| qty > 0 }
    end

    # 特定クーポンの選択数量を取得
    # @param discount [Discount] 割引
    # @return [Integer] 選択数量
    def coupon_quantity(discount)
      @coupon_quantities[discount.id] || 0
    end

    # PriceCalculator の計算結果（メモ化）
    def price_result
      @price_result ||= calculate_prices
    end

    def has_items_in_cart?
      items.any?(&:in_cart?)
    end

    # カート内の弁当合計数量
    def total_bento_quantity
      bento_items.select(&:in_cart?).sum(&:quantity)
    end

    def submittable?
      valid?
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

    def customer_type_present
      errors.add(:customer_type, :blank) unless customer_type.present?
    end

    def build_coupon_quantities(submitted)
      coupon_data = submitted["coupon"] || {}
      coupon_data.to_h.transform_keys(&:to_i).transform_values(&:to_i)
    end

    def calculate_prices
      return empty_result unless has_items_in_cart?

      calculator = Sales::PriceCalculator.new(
        cart_items_for_calculator,
        discount_quantities: discount_quantities_for_calculator
      )
      calculator.calculate
    rescue Errors::MissingPriceError
      empty_result
    end

    def empty_result
      {
        items_with_prices: [],
        subtotal: 0,
        discount_details: [],
        total_discount_amount: 0,
        final_total: 0
      }
    end
  end
end
