# frozen_string_literal: true

module Catalogs
  # 価格存在検証 PORO
  #
  # 指定された (catalog_id, kind, at) の価格が存在するかを検証する薄い部品。
  # 「何の kind が必要か」の判定は Sales::PriceCalculator が担当する（決定18参照）。
  #
  # @example 基本的な使い方
  #   validator = Catalog::PriceValidator.new
  #   validator.price_exists?(catalog_id, :regular)  # => true/false
  #
  # @example 過去の日付で検証
  #   validator = Catalog::PriceValidator.new(at: 1.month.ago.to_date)
  #   validator.find_price(catalog_id, :bundle)  # => CatalogPrice or nil
  #
  class PriceValidator
    # 価格が存在しない場合に発生する例外
    class MissingPriceError < StandardError
      attr_reader :catalog_name, :price_kind

      def initialize(catalog_name, price_kind)
        @catalog_name = catalog_name
        @price_kind = price_kind
        super("商品「#{catalog_name}」に価格種別「#{price_kind}」の価格が設定されていません")
      end
    end

    attr_reader :at

    # @param at [Date] 基準日（デフォルト: 今日）
    def initialize(at: Date.current)
      @at = at
    end

    # 指定された (catalog_id, kind) の価格が存在するか検証
    #
    # @param catalog_id [Integer] カタログID
    # @param kind [String, Symbol] 価格種別 ('regular' または 'bundle')
    # @return [Boolean] 価格が存在する場合は true
    def price_exists?(catalog_id, kind)
      CatalogPrice
        .where(catalog_id: catalog_id, kind: kind)
        .where("effective_from <= ?", at)
        .where("effective_until IS NULL OR effective_until >= ?", at)
        .exists?
    end

    # 価格を取得（存在しない場合は nil）
    #
    # @param catalog_id [Integer] カタログID
    # @param kind [String, Symbol] 価格種別
    # @return [CatalogPrice, nil] 価格が存在する場合は CatalogPrice、存在しない場合は nil
    def find_price(catalog_id, kind)
      CatalogPrice.current_price_by_kind!(catalog_id, kind)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    # 価格を取得（存在しない場合は MissingPriceError）
    #
    # @param catalog_id [Integer] カタログID
    # @param kind [String, Symbol] 価格種別
    # @return [CatalogPrice] 価格
    # @raise [MissingPriceError] 価格が存在しない場合
    def find_price!(catalog_id, kind)
      CatalogPrice.current_price_by_kind!(catalog_id, kind)
    rescue ActiveRecord::RecordNotFound
      catalog = ::Catalog.find(catalog_id)
      raise MissingPriceError.new(catalog.name, kind.to_s)
    end

    # 商品一覧用: 価格設定に不備がある商品を取得（Requirement 18）
    #
    # @return [Array<Hash>] 価格設定に不備がある商品のリスト
    #   各要素は { catalog: Catalog, missing_kinds: [String] } の形式
    def catalogs_with_missing_prices
      result = []

      ::Catalog.available.includes(:prices, :pricing_rules).find_each do |catalog|
        missing_kinds = []

        # 通常価格チェック（全商品で必須）
        missing_kinds << "regular" unless price_exists?(catalog.id, :regular)

        # 有効な価格ルールが参照する価格種別をチェック
        catalog.active_pricing_rules.each do |rule|
          next if rule.price_kind == "regular"
          missing_kinds << rule.price_kind unless price_exists?(catalog.id, rule.price_kind)
        end

        result << { catalog: catalog, missing_kinds: missing_kinds.uniq } if missing_kinds.any?
      end

      result
    end
  end
end
