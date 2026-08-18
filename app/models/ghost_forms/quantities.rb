# frozen_string_literal: true

module GhostForms
  # Ghost Form が送ってくる数量ハッシュを、送信キー側から全件読んで
  # `{Integer => Integer}` に変換する。
  #
  #   { "3" => { "quantity" => "2" }, "5" => { "quantity" => "0" } }
  #     → { 3 => 2, 5 => 0 }
  #
  # 販売カートのクーポンと返品の修正数量が同じ形を読むため、ここに集める。
  # カタログ側を主語に 1 件ずつ引く読み手（Sales::CartForm#build_items など）は
  # 走査の向きが逆なのでここを通らない。
  class Quantities
    # node が nil（キーごと届かなかった）なら空。数量が届かなかったキーは 0。
    # to_h は返り値を素の Hash に揃えるため（ParamsFilter は
    # HashWithIndifferentAccess を返す）。
    def self.from(node)
      return {} if node.nil?

      node.to_h.transform_keys(&:to_i).transform_values { |group| group["quantity"].to_i }
    end

    # 母集合 ids のキーを 1 つ残らず埋める。「届かなかったキーは 0」をこの 1 箇所だけで
    # 吸収するので、読み手は || 0 を書かずに添字アクセスしてよい。
    # 何を母集合とするか（画面が入力を描画する範囲）は呼び出し側の判断。
    def self.dense(ids, source)
      ids.index_with { |id| source[id] || 0 }
    end
  end
end
