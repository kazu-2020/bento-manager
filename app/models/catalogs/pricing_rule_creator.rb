# frozen_string_literal: true

module Catalogs
  # 価格ルール作成・更新 PORO
  #
  # 価格ルール（CatalogPricingRule）の作成・更新時に、参照する価格種別（kind）に
  # 対応する CatalogPrice が存在することを検証する。
  #
  # ActiveModel::Validations を使用して Rails 標準のバリデーションパターンに従う。
  #
  # @example 基本的な使い方
  #   creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)
  #   rule = creator.create(price_kind: :bundle, trigger_category: :bento, ...)
  #
  # @example 更新
  #   creator = Catalogs::PricingRuleCreator.new(target_catalog: rule.target_catalog)
  #   updated_rule = creator.update(rule, max_per_trigger: 2)
  #
  class PricingRuleCreator
    include ActiveModel::Validations

    attr_reader :target_catalog, :rule

    validate :validate_price_existence, if: :currently_active?

    # @param target_catalog [Catalog] 価格ルールを適用する商品
    def initialize(target_catalog:)
      @target_catalog = target_catalog
    end

    # 価格ルールを新規作成
    #
    # @param rule_params [Hash] ルールパラメータ
    # @option rule_params [Symbol, String] :price_kind 価格種別 (:regular, :bundle)
    # @option rule_params [Symbol, String] :trigger_category トリガーカテゴリ (:bento, :side_menu)
    # @option rule_params [Integer] :max_per_trigger トリガー1個あたりの最大適用数
    # @option rule_params [Date] :valid_from 有効開始日
    # @option rule_params [Date, nil] :valid_until 有効終了日（nil で無期限）
    # @return [CatalogPricingRule] 作成されたルール
    # @raise [Errors::MissingPriceError] 今日時点で有効なルールに対応する価格が存在しない場合
    # @raise [ActiveRecord::RecordInvalid] バリデーションエラーの場合
    def create(rule_params)
      @rule = CatalogPricingRule.new(rule_params.merge(target_catalog: target_catalog))
      validate_and_save!
    end

    # 価格ルールを更新
    #
    # @param existing_rule [CatalogPricingRule] 更新対象のルール
    # @param rule_params [Hash] 更新パラメータ
    # @return [CatalogPricingRule] 更新されたルール
    # @raise [Errors::MissingPriceError] 更新後に今日時点で有効になり、対応する価格が存在しない場合
    # @raise [ActiveRecord::RecordInvalid] バリデーションエラーの場合
    def update(existing_rule, rule_params)
      @rule = existing_rule
      rule.assign_attributes(rule_params)
      validate_and_save!
    end

    private

    # 価格存在を検証してルールを保存
    #
    # @return [CatalogPricingRule] 保存されたルール
    # @raise [Errors::MissingPriceError] 価格が存在しない場合
    def validate_and_save!
      raise Errors::MissingPriceError.new(missing_price_details) unless valid?

      rule.save!
      rule
    end

    # 今日時点で有効かどうかを判定
    #
    # @return [Boolean] 今日時点で有効な場合は true
    def currently_active?
      return false unless rule&.valid_from

      today = Date.current
      started = rule.valid_from <= today
      not_ended = rule.valid_until.nil? || rule.valid_until >= today

      started && not_ended
    end

    # 価格存在検証（ActiveModel::Validations のカスタムバリデーション）
    def validate_price_existence
      return if price_exists?

      errors.add(:base, :missing_price, catalog_name: target_catalog.name, price_kind: rule.price_kind)
    end

    # 対象カタログに指定価格種別が存在するか
    #
    # @return [Boolean]
    def price_exists?
      Catalogs::PriceValidator.new(at: Date.current).price_exists?(target_catalog, rule.price_kind)
    end

    # MissingPriceError 用の詳細情報
    #
    # @return [Array<Hash>] 欠損価格の詳細
    def missing_price_details
      [ {
        catalog_id: target_catalog.id,
        catalog_name: target_catalog.name,
        price_kind: rule.price_kind.to_s
      } ]
    end
  end
end
