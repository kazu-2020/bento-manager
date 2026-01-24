# frozen_string_literal: true

module Catalogs
  # カタログ作成クラスのファクトリー
  #
  # カテゴリに応じた Creator クラスを生成する。
  #
  # @example
  #   creator = Catalogs::CreatorFactory.build("bento", name: "のり弁当", regular_price: 450)
  #   creator.create!
  #
  class CreatorFactory
    # 不正なカテゴリが指定された場合に発生するエラー
    class InvalidCategoryError < ArgumentError; end

    # カテゴリに応じた Creator インスタンスを生成
    #
    # @param category [String] カテゴリ ("bento" or "side_menu")
    # @param attributes [Hash] Creator の属性
    # @return [BentoCreator, SideMenuCreator] Creator インスタンス
    # @raise [InvalidCategoryError] 不明なカテゴリの場合
    def self.build(category, attributes = {})
      creator_class_for(category).new(attributes)
    end

    # カテゴリに応じた Creator クラスを返す
    #
    # @param category [String] カテゴリ ("bento" or "side_menu")
    # @return [Class] Creator クラス
    # @raise [InvalidCategoryError] 不明なカテゴリの場合
    def self.creator_class_for(category)
      case category
      when "bento" then BentoCreator
      when "side_menu" then SideMenuCreator
      else
        raise InvalidCategoryError, "Unknown category: #{category}"
      end
    end
  end
end
