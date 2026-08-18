# frozen_string_literal: true

module Refunds
  # 修正カートの内容から、修正後の販売の金額と元の販売との差額を組み立てる。
  #
  # 3 つの状態を同じインターフェースの奥に畳む。呼び出し側はどれなのかを気にしなくてよい。
  #   1. 修正カートに手が入っていない  → すべて 0 と空配列（null object）
  #   2. 修正後の商品が無い / 価格が引けない → 修正後は 0 円。元の販売のクーポンを「返却」として並べる
  #   3. 通常                          → Sales::PriceCalculator の結果
  class Preview
    UNCHANGED_RESULT = {
      final_total: 0,
      items_with_prices: [].freeze,
      discount_details: [].freeze,
      total_discount_amount: 0
    }.freeze

    # @param sale [Sale] 元の販売
    # @param items [Array<Hash>] 修正後の商品 [{ catalog:, quantity: }, ...]
    # @param discount_quantities [Hash{Integer => Integer}] 修正後のクーポン枚数
    # @param changed [Boolean] 修正カートに手が入っているか
    def initialize(sale:, items:, discount_quantities:, changed:)
      @sale = sale
      @items = items
      @discount_quantities = discount_quantities
      @changed = changed
    end

    def final_total
      result[:final_total]
    end

    def items_with_prices
      result[:items_with_prices]
    end

    def discount_details
      result[:discount_details]
    end

    def total_discount_amount
      result[:total_discount_amount]
    end

    # 元の販売との差額。正なら返金、負なら追加請求
    def adjustment_amount
      return 0 unless changed?

      sale.final_amount - final_total
    end

    def adjustment_type
      amount = adjustment_amount
      if amount.positive?
        :refund
      elsif amount.negative?
        :additional_charge
      else
        :even_exchange
      end
    end

    private

    attr_reader :sale, :items, :discount_quantities

    def changed?
      @changed
    end

    def result
      @result ||= build_result
    end

    def build_result
      return UNCHANGED_RESULT unless changed?
      return full_refund_result if items.empty?

      calculated_result
    end

    def calculated_result
      Sales::PriceCalculator.new(items, discount_quantities: discount_quantities).calculate
    rescue Errors::MissingPriceError => e
      Rails.logger.error "[Refunds::Preview] MissingPriceError: #{e.message}"
      full_refund_result
    end

    # 修正後の商品が無ければ修正後の販売は作られない。元の販売で使ったクーポンは
    # 1 枚も適用されないまま客の手元に戻るので、返却として並べる
    def full_refund_result
      {
        final_total: 0,
        items_with_prices: [],
        discount_details: returned_discount_details,
        total_discount_amount: 0
      }
    end

    def returned_discount_details
      sale.sale_discounts.eager_load(:discount).map do |sale_discount|
        {
          discount_id: sale_discount.discount_id,
          discount_name: sale_discount.discount.name,
          discount_amount: 0,
          quantity: 0,
          requested_quantity: sale_discount.quantity,
          applicable: false
        }
      end
    end
  end
end
