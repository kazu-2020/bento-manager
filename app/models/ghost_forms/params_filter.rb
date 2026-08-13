# frozen_string_literal: true

module GhostForms
  # Ghost Form で送られてくる動的キーのハッシュを、構造を検証したうえで素のハッシュにする。
  #
  # 送信キーが catalog_id や discount_id といった実行時にしか決まらない値のため、
  # permit のホワイトリストを静的には書けない。代わりに「どの位置に何の型が来るか」を
  # フォーム側に宣言させ、宣言と合わない値をすべて破棄する。深さから型を推測すると
  # 宣言のない位置に scalar が紛れ込み、フォームの `v["quantity"]` が型エラーで 500 する。
  #
  # 受け取れる構造は 3 種類だけ。
  #
  #   scalar     : cart["customer_type"]
  #   group      : cart["<catalog_id>"]["quantity"]
  #   collection : cart["coupon"]["<discount_id>"]["quantity"]
  class ParamsFilter
    # group と collection のキーは catalog_id / discount_id なので数値に限る。
    # 許すとフォーム側の `transform_keys(&:to_i)` が "abc" を 0 に潰し、
    # 存在しない商品を変更ありと誤判定する。
    ID_KEY = /\A\d+\z/

    class << self
      # scalar_keys      最上位で scalar を受け取るキー
      # collection_keys  最上位で group の集まりを受け取るキー
      # どちらの宣言もない最上位キーは group とみなす（商品 ID を名前空間とするため）
      def call(node, scalar_keys: [], collection_keys: [])
        filter(node) do |name, value|
          if scalar_keys.include?(name)
            value if scalar?(value)
          elsif collection_keys.include?(name)
            collection(value)
          elsif id?(name) && hash?(value)
            group(value)
          end
        end.with_indifferent_access
      end

      private

      # group の集まり。ID 以外のキーと group 以外の値は破棄する
      def collection(node)
        filter(node) { |name, value| group(value) if id?(name) && hash?(value) }
      end

      # ひとつの名前空間。scalar の葉だけを残す
      def group(node)
        filter(node) { |_name, value| value if scalar?(value) }
      end

      # 各キーをブロックに通し、値を返したものだけを残す
      def filter(node)
        return {} unless hash?(node)

        filtered = {}
        node.each_pair do |key, value|
          kept = yield(key.to_s, value)
          filtered[key.to_s] = kept unless kept.nil?
        end
        filtered
      end

      def hash?(node)
        node.respond_to?(:each_pair)
      end

      def id?(name)
        ID_KEY.match?(name)
      end

      # 葉は String に限る。form-encoded の HTTP は常に String を返すので実害はなく、
      # 型変換はフォーム側の責務にできる。JSON ボディなら数値も真偽値も送れてしまい、
      # 葉に掛かる `.to_i` や `.to_sym` が NoMethodError で 500 する
      # （`true.to_i` / `1.to_sym`）。ActionController の PERMITTED_SCALAR_TYPES は
      # Date や IO まで含むので流用できない。
      def scalar?(value)
        value.is_a?(String)
      end
    end
  end
end
