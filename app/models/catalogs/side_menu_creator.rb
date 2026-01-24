# frozen_string_literal: true

module Catalogs
  # サイドメニューカタログ作成クラス
  #
  # Catalog (category: side_menu) + CatalogPrice (kind: regular, bundle) +
  # CatalogPricingRule をトランザクション内で一括作成する。
  #
  # @example 通常価格のみ
  #   creator = Catalogs::SideMenuCreator.new(
  #     name: "唐揚げ",
  #     regular_price: 150
  #   )
  #   catalog = creator.create!
  #
  # @example セット価格あり
  #   creator = Catalogs::SideMenuCreator.new(
  #     name: "唐揚げ",
  #     regular_price: 150,
  #     bundle_price: 100
  #   )
  #   catalog = creator.create!
  #
  class SideMenuCreator < BaseCreator
    attribute :bundle_price, :integer

    validate :validate_bundle_price, if: -> { bundle_price.present? }

    # セット価格レコードへの公開アクセサ（ビューからエラー参照用）
    def bundle_price_record
      built_bundle_price
    end

    def create!
      ActiveRecord::Base.transaction do
        built_regular_price
        built_bundle_price if bundle_price.present?
        save_catalog!
        create_pricing_rule! if bundle_price.present?
      end

      catalog
    end

    private

    def category
      "side_menu"
    end

    def validate_bundle_price
      copy_errors_from(built_bundle_price, price: :bundle_price)
    end

    # セット価格を構築（バリデーションと保存で同じインスタンスを使用）
    def built_bundle_price
      return unless bundle_price.present?

      @bundle_price_record ||= built_catalog.prices.build(
        kind: :bundle,
        price: bundle_price,
        effective_from: Time.current
      )
    end

    def create_pricing_rule!
      CatalogPricingRule.create!(
        target_catalog: catalog,
        price_kind: :bundle,
        trigger_category: :bento,
        max_per_trigger: 1,
        valid_from: Date.current
      )
    end
  end
end
