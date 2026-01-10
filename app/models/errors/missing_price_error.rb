# frozen_string_literal: true

module Errors
  # 価格が存在しない場合に発生する例外
  #
  # @example
  #   raise Errors::MissingPriceError.new([
  #     { catalog_id: 1, catalog_name: "弁当A", price_kind: "regular" },
  #     { catalog_id: 2, catalog_name: "サラダ", price_kind: "bundle" }
  #   ])
  #
  class MissingPriceError < StandardError
    attr_reader :missing_prices

    # @param missing_prices [Array<Hash>] 欠損価格のリスト
    #   各要素は { catalog_id:, catalog_name:, price_kind: } の形式
    def initialize(missing_prices)
      @missing_prices = missing_prices
      super(build_message)
    end

    private

    def build_message
      return "価格設定エラー" if @missing_prices.empty?

      messages = @missing_prices.map do |mp|
        "商品「#{mp[:catalog_name]}」に価格種別「#{mp[:price_kind]}」の価格が設定されていません"
      end

      if messages.one?
        messages.first
      else
        "価格設定エラー: #{messages.join('; ')}"
      end
    end
  end
end
