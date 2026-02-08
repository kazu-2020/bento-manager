# frozen_string_literal: true

module Refunds
  class RefundForm
    include ActiveModel::Model
    include Rails.application.routes.url_helpers

    attr_reader :sale, :location, :corrected_quantities, :coupon_quantities, :inventories

    validate :at_least_one_change

    def initialize(sale:, location:, inventories: [], submitted: {})
      @sale = sale
      @location = location
      @inventories = inventories
      @corrected_quantities = build_corrected_quantities(submitted)
      @coupon_quantities = build_coupon_quantities(submitted)
    end

    def corrected_items
      @corrected_items ||= build_corrected_items
    end

    def corrected_items_for_refunder
      @corrected_items_for_refunder ||= corrected_quantities.filter_map do |catalog_id, qty|
        next if qty <= 0
        catalog = find_catalog(catalog_id)
        next unless catalog
        { catalog: catalog, quantity: qty }
      end
    end

    def discount_quantities_for_refunder
      coupon_quantities.select { |_, qty| qty > 0 }
    end

    def has_any_changes?
      quantities_changed? || coupons_changed?
    end

    def all_items_zero?
      corrected_quantities.values.all?(&:zero?)
    end

    def preview_price_result
      return nil unless has_any_changes?

      @preview_price_result ||= calculate_preview_prices
    end

    def preview_adjustment_amount
      return 0 unless has_any_changes?

      corrected_amount = preview_price_result[:final_total]
      sale.final_amount - corrected_amount
    end

    def adjustment_type
      amount = preview_adjustment_amount
      if amount.positive?
        :refund
      elsif amount.negative?
        :additional_charge
      else
        :even_exchange
      end
    end

    def total_corrected_bento_quantity
      corrected_quantities.sum do |catalog_id, qty|
        catalog = find_catalog(catalog_id)
        catalog&.category == "bento" ? qty : 0
      end
    end

    def tab_items
      @tab_items ||= begin
        items = []
        items << { key: :bento, label: I18n.t("enums.catalog.category.bento") } if bento_corrected_items.any?
        items << { key: :side_menu, label: I18n.t("enums.catalog.category.side_menu") } if side_menu_corrected_items.any?
        items << { key: :coupon, label: I18n.t("enums.catalog.category.coupon") } if available_discounts.any?
        items
      end
    end

    def bento_corrected_items
      @bento_corrected_items ||= corrected_items.select { |item| item.category == "bento" }
    end

    def side_menu_corrected_items
      @side_menu_corrected_items ||= corrected_items.select { |item| item.category == "side_menu" }
    end

    def available_discounts
      @available_discounts ||= Discount.active_at(Date.current)
    end

    def form_with_options
      { url: pos_location_refunds_path(location), method: :post }
    end

    def form_state_options
      { url: pos_location_refunds_form_state_path(location), method: :post }
    end

    private

    def build_corrected_quantities(submitted)
      corrected_data = submitted["corrected"] || {}

      if corrected_data.empty?
        # 初期値: 元の販売の商品数量 + 在庫にある未購入商品は0
        default_corrected_quantities
      else
        corrected_data.transform_keys(&:to_i).transform_values { |v| v["quantity"].to_i }
      end
    end

    def build_coupon_quantities(submitted)
      coupon_data = submitted["coupon"] || {}

      if coupon_data.empty?
        original_discount_quantities
      else
        coupon_data.transform_keys(&:to_i).transform_values { |v| v["quantity"].to_i }
      end
    end

    def default_corrected_quantities
      quantities = {}

      # 元の販売の商品数量
      sale.items.group_by(&:catalog_id).each do |catalog_id, items|
        quantities[catalog_id] = items.sum(&:quantity)
      end

      # 在庫にある未購入商品は0
      inventories.each do |inventory|
        quantities[inventory.catalog_id] ||= 0
      end

      quantities
    end

    def original_discount_quantities
      sale.sale_discounts.pluck(:discount_id, :quantity).to_h
    end

    def quantities_changed?
      original = sale.items.group_by(&:catalog_id).transform_values { |items| items.sum(&:quantity) }

      corrected_quantities.any? do |catalog_id, qty|
        original_qty = original[catalog_id] || 0
        qty != original_qty
      end
    end

    def coupons_changed?
      original = original_discount_quantities

      coupon_quantities.any? do |discount_id, qty|
        original_qty = original[discount_id] || 0
        qty != original_qty
      end
    end

    def at_least_one_change
      errors.add(:base, :no_items_selected) unless has_any_changes?
    end

    def find_catalog(catalog_id)
      # まず元の販売から探す
      sale_item = sale.items.find { |item| item.catalog_id == catalog_id }
      return sale_item.catalog if sale_item

      # 在庫から探す
      inventories.find { |inv| inv.catalog_id == catalog_id }&.catalog
    end

    def calculate_preview_prices
      items = corrected_items_for_refunder
      if items.empty?
        return {
          final_total: 0,
          items_with_prices: [],
          discount_details: build_full_refund_discount_details,
          total_discount_amount: 0
        }
      end

      calculator = Sales::PriceCalculator.new(
        items,
        discount_quantities: discount_quantities_for_refunder
      )
      calculator.calculate
    rescue Errors::MissingPriceError => e
      Rails.logger.error "[RefundForm] MissingPriceError: #{e.message}"
      { final_total: 0, items_with_prices: [], discount_details: build_full_refund_discount_details, total_discount_amount: 0 }
    end

    def build_full_refund_discount_details
      sale.sale_discounts.includes(:discount).map do |sd|
        {
          discount_id: sd.discount_id,
          discount_name: sd.discount.name,
          discount_amount: 0,
          quantity: 0,
          requested_quantity: sd.quantity,
          applicable: false
        }
      end
    end

    def build_corrected_items
      all_catalog_ids = (
        sale.items.map(&:catalog_id) +
        inventories.map(&:catalog_id)
      ).uniq

      all_catalog_ids.filter_map do |catalog_id|
        catalog = find_catalog(catalog_id)
        next unless catalog

        quantity = corrected_quantities[catalog_id] || 0
        original_qty = sale.items.select { |i| i.catalog_id == catalog_id }.sum(&:quantity)
        inventory = inventories.find { |inv| inv.catalog_id == catalog_id }
        available_stock = inventory&.available_stock || 0
        # 在庫上限 = 元の数量 + 利用可能在庫（返品分の在庫は復元されるため）
        max_quantity = original_qty + available_stock

        CorrectedItem.new(
          catalog: catalog,
          quantity: quantity,
          original_quantity: original_qty,
          max_quantity: max_quantity,
          inventory: inventory
        )
      end
    end

    # 修正カート内のアイテムを表すクラス
    class CorrectedItem
      attr_reader :catalog, :quantity, :original_quantity, :max_quantity, :inventory

      delegate :id, :name, :category, to: :catalog, prefix: true

      def initialize(catalog:, quantity:, original_quantity:, max_quantity:, inventory: nil)
        @catalog = catalog
        @quantity = quantity
        @original_quantity = original_quantity
        @max_quantity = max_quantity
        @inventory = inventory
      end

      def category
        catalog_category
      end

      def changed?
        quantity != original_quantity
      end

      def in_cart?
        quantity > 0
      end

      def unit_price
        catalog.price_by_kind(:regular)&.price
      end

      def sold_out?
        max_quantity <= 0
      end
    end
  end
end
