# frozen_string_literal: true

module Catalogs
  # 価格存在検証 PORO
  #
  # 指定された (catalog, kind, at) の価格が存在するかを検証する薄い部品。
  # 「何の kind が必要か」の判定は Sales::PriceCalculator が担当する（決定18参照）。
  #
  # @example 基本的な使い方
  #   validator = Catalogs::PriceValidator.new
  #   validator.price_exists?(catalog, :regular)  # => true/false
  #
  # @example 過去の日時で検証
  #   validator = Catalogs::PriceValidator.new(at: 1.month.ago)
  #   validator.find_price(catalog, :bundle)  # => CatalogPrice or nil
  #
  class PriceValidator
    attr_reader :at

    # @param at [Time] 基準日時（デフォルト: 現在）
    def initialize(at: Time.current)
      @at = at
    end

    # 指定された (catalog, kind) の価格が存在するか検証
    #
    # @param catalog [Catalog] カタログ
    # @param kind [String, Symbol] 価格種別 ('regular' または 'bundle')
    # @return [Boolean] 価格が存在する場合は true
    def price_exists?(catalog, kind)
      catalog.price_exists?(kind, at: at)
    end

    # 価格を取得（存在しない場合は nil）
    #
    # @param catalog [Catalog] カタログ
    # @param kind [String, Symbol] 価格種別
    # @return [CatalogPrice, nil] 価格が存在する場合は CatalogPrice、存在しない場合は nil
    def find_price(catalog, kind)
      catalog.price_by_kind(kind, at: at)
    end

    # 価格を取得（存在しない場合は MissingPriceError）
    #
    # @param catalog [Catalog] カタログ
    # @param kind [String, Symbol] 価格種別
    # @return [CatalogPrice] 価格
    # @raise [Errors::MissingPriceError] 価格が存在しない場合
    def find_price!(catalog, kind)
      catalog.price_by_kind(kind, at: at) ||
        raise(Errors::MissingPriceError.new([ { catalog_name: catalog.name, price_kind: kind.to_s } ]))
    end

    # 商品一覧用: 価格設定に不備がある商品を取得（Requirement 18）
    #
    # @return [Array<Hash>] 価格設定に不備がある商品のリスト
    #   各要素は { catalog: Catalog, missing_kinds: [String] } の形式
    def catalogs_with_missing_prices
      result = []

      ::Catalog.available.preload(:active_pricing_rules).find_each do |catalog|
        missing_kinds = []

        # 通常価格チェック（全商品で必須）
        missing_kinds << "regular" unless catalog.price_exists?(:regular, at: at)

        # 有効な価格ルールが参照する価格種別をチェック
        catalog.active_pricing_rules.each do |rule|
          next if rule.price_kind == "regular"
          missing_kinds << rule.price_kind unless catalog.price_exists?(rule.price_kind, at: at)
        end

        result << { catalog: catalog, missing_kinds: missing_kinds.uniq } if missing_kinds.any?
      end

      result
    end
  end
end
