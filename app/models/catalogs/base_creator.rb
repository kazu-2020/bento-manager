# frozen_string_literal: true

module Catalogs
  # 商品カタログ作成の基底クラス
  #
  # 共通の属性とメソッドを定義する抽象基底クラス。
  # 具象クラス（BentoCreator, SideMenuCreator）で継承して使用する。
  #
  class BaseCreator
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :description, :string, default: ""
    attribute :regular_price, :integer

    validate :validate_catalog
    validate :validate_regular_price

    # 構築したカタログを返す（バリデーションと保存で同じインスタンスを使用）
    def built_catalog
      @catalog ||= Catalog.new(name: name, category: category, description: description)
    end

    # 外部から参照するためのエイリアス
    alias catalog built_catalog

    # 通常価格レコードへの公開アクセサ（ビューからエラー参照用）
    def regular_price_record
      built_regular_price
    end

    # form_with で使用するためのメソッド
    def persisted?
      false
    end

    # モデル名を返す（form_with のルーティング用）
    def self.model_name
      ActiveModel::Name.new(self, nil, "Catalog")
    end

    # 商品カタログを作成
    #
    # @return [Catalog] 作成されたカタログ
    # @raise [ActiveRecord::RecordInvalid] バリデーションエラーの場合
    def create!
      raise NotImplementedError, "Subclasses must implement #create!"
    end

    # 商品カタログを作成（例外を発生させない）
    #
    # @return [Catalog, nil] 作成されたカタログ、失敗時は nil
    def create
      create!
    rescue ActiveRecord::RecordInvalid
      nil
    end

    private

    # カテゴリを返す（サブクラスで実装）
    #
    # @return [String] カテゴリ名
    def category
      raise NotImplementedError, "Subclasses must implement #category"
    end

    # Catalog のバリデーション
    def validate_catalog
      copy_errors_from(built_catalog)
    end

    # 通常価格のバリデーション
    def validate_regular_price
      copy_errors_from(built_regular_price, price: :regular_price)
    end

    # 通常価格を構築（バリデーションと保存で同じインスタンスを使用）
    def built_regular_price
      @regular_price ||= built_catalog.prices.build(
        kind: :regular,
        price: regular_price,
        effective_from: Time.current
      )
    end

    # モデルのエラーを自身にコピー
    #
    # @param record [ActiveRecord::Base] エラー元のレコード
    # @param attribute_mapping [Hash] 属性名のマッピング（例: { price: :regular_price }）
    def copy_errors_from(record, attribute_mapping = {})
      return if record.valid?

      record.errors.each do |error|
        attr = attribute_mapping.fetch(error.attribute, error.attribute)
        errors.add(attr, error.message)
      end
    end

    # 構築済みのカタログを保存（関連する prices も一緒に保存される）
    def save_catalog!
      built_catalog.save!
    end
  end
end
