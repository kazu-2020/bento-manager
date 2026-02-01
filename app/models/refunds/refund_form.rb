# frozen_string_literal: true

module Refunds
  class RefundForm
    include ActiveModel::Model
    include Rails.application.routes.url_helpers

    attr_reader :sale, :location, :catalog_refund_quantities

    validate :at_least_one_item_to_refund

    def initialize(sale:, location:, submitted: {})
      @sale = sale
      @location = location
      @catalog_refund_quantities = parse_refund_quantities(submitted)
      @submitting = submitted["_submitting"] == "true"
    end

    def items
      @items ||= sale.items.map do |sale_item|
        RefundItem.new(sale_item: sale_item)
      end
    end

    def grouped_items
      @grouped_items ||= items.group_by(&:catalog_id).map do |catalog_id, group_items|
        total = group_items.sum(&:quantity)
        raw_quantity = catalog_refund_quantities[catalog_id] || 0
        safe_quantity = raw_quantity.clamp(0, total)

        RefundItemGroup.new(
          items: group_items,
          refund_quantity: safe_quantity
        )
      end
    end

    def selected_items
      grouped_items.select(&:selected?)
    end

    def remaining_items
      grouped_items.reject { |group| group.remaining_quantity <= 0 }
    end

    def has_selected_items?
      grouped_items.any?(&:selected?)
    end

    def all_items_selected?
      grouped_items.none? { |group| group.remaining_quantity > 0 }
    end

    def remaining_items_for_refunder
      grouped_items.filter_map do |group|
        remaining = group.remaining_quantity
        next if remaining <= 0
        { catalog: group.catalog, quantity: remaining }
      end
    end

    def preview_price_result
      return nil unless has_selected_items?

      @preview_price_result ||= calculate_preview_prices
    end

    def preview_refund_amount
      return 0 unless has_selected_items?

      corrected_amount = preview_price_result[:final_total]
      sale.final_amount - corrected_amount
    end

    def form_with_options
      { url: pos_location_refunds_path(location), method: :post }
    end

    def form_state_options
      { url: pos_location_refunds_form_state_path(location), method: :post }
    end

    private

    def submitting?
      @submitting
    end

    def parse_refund_quantities(submitted)
      catalogs_data = submitted["catalogs"] || {}
      catalogs_data.transform_keys(&:to_i).transform_values { |v| v["refund_quantity"].to_i }
    end

    def at_least_one_item_to_refund
      errors.add(:base, :no_items_selected) unless has_selected_items?
    end

    def calculate_preview_prices
      return { final_total: 0, items_with_prices: [] } if all_items_selected?

      calculator = Sales::PriceCalculator.new(
        remaining_items_for_refunder,
        discount_quantities: extract_discount_quantities
      )
      calculator.calculate
    rescue Errors::MissingPriceError => e
      Rails.logger.error "[RefundForm] MissingPriceError: #{e.message}"
      { final_total: 0, items_with_prices: [] }
    end

    def extract_discount_quantities
      sale.sale_discounts.pluck(:discount_id, :quantity).to_h
    end

    # 返品商品を表すラッパークラス
    class RefundItem
      attr_reader :sale_item

      delegate :id, :catalog, :catalog_id, :catalog_price, :quantity, :unit_price, :line_total, to: :sale_item

      def initialize(sale_item:)
        @sale_item = sale_item
      end

      def catalog_name
        catalog.name
      end

      def category
        catalog.category
      end

      def bundle_price?
        catalog_price.bundle?
      end
    end

    # 同じカタログの商品をグループ化するクラス
    class RefundItemGroup
      attr_reader :items, :refund_quantity

      def initialize(items:, refund_quantity: 0)
        @items = items
        @refund_quantity = refund_quantity
      end

      def catalog
        items.first.catalog
      end

      def catalog_id
        catalog.id
      end

      def catalog_name
        catalog.name
      end

      def category
        catalog.category
      end

      def total_quantity
        items.sum(&:quantity)
      end

      def total_line_total
        items.sum(&:line_total)
      end

      def remaining_quantity
        total_quantity - refund_quantity
      end

      def selected?
        refund_quantity > 0
      end

      def single_price_type?
        items.size == 1
      end
    end
  end
end
