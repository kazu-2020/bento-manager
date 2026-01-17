# frozen_string_literal: true

module Catalogs
  # 弁当カタログ作成クラス
  #
  # Catalog (category: bento) + CatalogPrice (kind: regular) を
  # トランザクション内で一括作成する。
  #
  # @example
  #   creator = Catalogs::BentoCreator.new(
  #     name: "のり弁当",
  #     regular_price: 450
  #   )
  #   catalog = creator.create!
  #
  class BentoCreator < BaseCreator
    def create!
      ActiveRecord::Base.transaction do
        built_regular_price  # prices を構築
        save_catalog!        # catalog と prices を一緒に保存
      end

      catalog
    end

    private

    def category
      "bento"
    end
  end
end
