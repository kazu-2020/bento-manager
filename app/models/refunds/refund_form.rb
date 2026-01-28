# frozen_string_literal: true

module Refunds
  class RefundForm
    include ActiveModel::Model
    include Rails.application.routes.url_helpers

    attr_reader :sale, :location, :reason, :selected_item_ids

    validate :at_least_one_item_to_refund
    validates :reason, presence: true, if: :submitting?

    def initialize(sale:, location:, submitted: {})
      @sale = sale
      @location = location
      @reason = submitted["reason"] || ""
      @selected_item_ids = parse_selected_item_ids(submitted)
      @submitting = submitted["_submitting"] == "true"
    end

    def items
      @items ||= sale.items.map do |sale_item|
        RefundItem.new(
          sale_item: sale_item,
          selected: selected_item_ids.include?(sale_item.id)
        )
      end
    end

    def selected_items
      items.select(&:selected?)
    end

    def remaining_items
      items.reject(&:selected?)
    end

    def has_selected_items?
      items.any?(&:selected?)
    end

    def all_items_selected?
      items.all?(&:selected?)
    end

    def remaining_items_for_refunder
      remaining_items.map do |item|
        { catalog: item.catalog, quantity: item.quantity }
      end
    end

    def preview_price_result
      return nil unless has_selected_items?

      @preview_price_result ||= calculate_preview_prices
    end

    def preview_refund_amount
      return 0 unless has_selected_items?

      corrected_amount = preview_price_result&.dig(:final_total) || 0
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

    def parse_selected_item_ids(submitted)
      items_data = submitted["items"] || {}
      items_data.select { |_, v| v["refund"] == "1" }.keys.map(&:to_i)
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

      delegate :id, :catalog, :quantity, :unit_price, :line_total, to: :sale_item

      def initialize(sale_item:, selected:)
        @sale_item = sale_item
        @selected = selected
      end

      def selected?
        @selected
      end

      def catalog_name
        catalog.name
      end

      def category
        catalog.category
      end
    end
  end
end
