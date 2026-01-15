# frozen_string_literal: true

module Catalogs
  # 商品カタログ作成 PORO
  #
  # Catalog + CatalogPrice + (optional) CatalogPricingRule を
  # トランザクション内で一括作成する。
  #
  # @example 弁当の作成
  #   creator = Catalogs::Creator.new(
  #     name: "のり弁当",
  #     category: "bento",
  #     regular_price: 450
  #   )
  #   catalog = creator.create!
  #
  # @example サイドメニューの作成（セット価格あり）
  #   creator = Catalogs::Creator.new(
  #     name: "唐揚げ",
  #     category: "side_menu",
  #     regular_price: 150,
  #     bundle_price: 100
  #   )
  #   catalog = creator.create!
  #
  class Creator
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :category, :string
    attribute :description, :string, default: ""
    attribute :regular_price, :integer
    attribute :bundle_price, :integer

    validates :name, presence: true
    validates :category, presence: true, inclusion: { in: %w[bento side_menu] }
    validates :regular_price, presence: true, numericality: { greater_than: 0 }
    validates :bundle_price, numericality: { greater_than: 0 }, allow_blank: true
    validate :bundle_price_for_side_menu_only
    validate :bundle_price_less_than_regular

    attr_reader :catalog

    # 商品カタログを作成
    #
    # @return [Catalog] 作成されたカタログ
    # @raise [ActiveModel::ValidationError] バリデーションエラーの場合
    def create!
      raise ActiveModel::ValidationError, self unless valid?

      ActiveRecord::Base.transaction do
        create_catalog!
        create_regular_price!
        create_bundle_price_and_rule! if bundle_price.present?
      end

      catalog
    end

    # 商品カタログを作成（例外を発生させない）
    #
    # @return [Catalog, nil] 作成されたカタログ、失敗時は nil
    def create
      create!
    rescue ActiveModel::ValidationError, ActiveRecord::RecordInvalid
      nil
    end

    private

    def bundle_price_for_side_menu_only
      return unless bundle_price.present? && category != "side_menu"

      errors.add(:bundle_price, "はサイドメニューにのみ設定できます")
    end

    def bundle_price_less_than_regular
      return unless bundle_price.present? && regular_price.present?
      return if bundle_price < regular_price

      errors.add(:bundle_price, "は通常価格より低く設定してください")
    end

    def create_catalog!
      @catalog = Catalog.create!(
        name: name,
        category: category,
        description: description
      )
    end

    def create_regular_price!
      catalog.prices.create!(
        kind: :regular,
        price: regular_price,
        effective_from: Time.current
      )
    end

    def create_bundle_price_and_rule!
      catalog.prices.create!(
        kind: :bundle,
        price: bundle_price,
        effective_from: Time.current
      )

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
