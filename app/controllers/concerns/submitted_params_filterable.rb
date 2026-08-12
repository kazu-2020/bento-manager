# frozen_string_literal: true

# Ghost Form パターンで送られてくる動的キーのハッシュを、構造を検証したうえで取り出す。
#
# 送信キーが catalog_id や discount_id といった実行時にしか決まらない値のため、
# permit のホワイトリストを静的には書けない。代わりに「どの位置に何の型が来るか」を
# 呼び出し側に宣言させ、宣言と合わない値をすべて破棄する。深さから型を推測すると
# 宣言のない位置に scalar が紛れ込み、フォームオブジェクトの `v["quantity"]` が
# 型エラーで 500 になるため、位置ごとに型を固定することが要点。
#
# 受け取れる構造は 3 種類だけで、いずれも葉は scalar に限る。
#
#   scalar     : cart["customer_type"]
#   group      : cart["<catalog_id>"]["quantity"]
#   collection : cart["coupon"]["<discount_id>"]["quantity"]
module SubmittedParamsFilterable
  extend ActiveSupport::Concern

  # 葉が取れる型。フォーム側は葉に `.to_i` / `.to_s` を掛けるため、それに応答する型に限る。
  # JSON ボディなら真偽値や null も送れてしまい、`true.to_i` が NoMethodError で 500 する。
  SCALAR_TYPES = [ String, Numeric ].freeze

  # group と collection のキーは catalog_id / discount_id なので数値に限る。
  # 許すとフォーム側の `transform_keys(&:to_i)` が "abc" を 0 に潰し、
  # 存在しない商品を変更ありと誤判定する。
  ID_KEY = /\A\d+\z/

  private

  # scalar_keys      最上位で scalar を受け取るキー
  # collection_keys  最上位で group の集まりを受け取るキー
  # どちらの宣言もない最上位キーは group とみなす（商品 ID を名前空間とするため）
  def submitted_params(key, scalar_keys: [], collection_keys: [])
    scalars = Array(scalar_keys).map(&:to_s)
    collections = Array(collection_keys).map(&:to_s)
    filtered = {}

    each_param_pair(params[key]) do |name, value|
      if scalars.include?(name)
        filtered[name] = value if scalar_param?(value)
      elsif collections.include?(name)
        filtered[name] = filtered_collection(value)
      elsif id_key?(name) && hash_param?(value)
        filtered[name] = filtered_group(value)
      end
    end

    filtered.with_indifferent_access
  end

  # group の集まり。ID 以外のキーと group 以外の値は破棄する
  def filtered_collection(node)
    collection = {}

    each_param_pair(node) do |name, value|
      collection[name] = filtered_group(value) if id_key?(name) && hash_param?(value)
    end

    collection
  end

  # ひとつの名前空間。scalar の葉だけを残す
  def filtered_group(node)
    group = {}

    each_param_pair(node) do |name, value|
      group[name] = value if scalar_param?(value)
    end

    group
  end

  def each_param_pair(node)
    return unless hash_param?(node)

    node.each_pair { |key, value| yield(key.to_s, value) }
  end

  def hash_param?(node)
    node.respond_to?(:each_pair)
  end

  def id_key?(name)
    ID_KEY.match?(name)
  end

  def scalar_param?(value)
    SCALAR_TYPES.any? { |type| value.is_a?(type) }
  end
end
