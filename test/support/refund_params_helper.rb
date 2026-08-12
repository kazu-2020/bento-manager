# 差額精算フォームのパラメータ組み立てヘルパー
#
# 確定用（refund）と Ghost Form 用（ghost_refund）で名前空間だけが異なり、
# 中身の形は同じ。名前空間は呼び出し側が与える。
module RefundParamsHelper
  # 修正後の数量をフォームのパラメータ形式に変換する
  #
  # @param corrected [Hash{Catalog => Integer}] 修正後の商品数量
  # @param coupon [Hash{Discount => Integer}] 修正後のクーポン枚数
  # @return [Hash] { corrected: { "<id>" => { quantity: "<n>" } }, coupon: {...} }
  def refund_quantity_params(corrected: {}, coupon: {})
    {
      corrected: quantity_fields(corrected),
      coupon: quantity_fields(coupon)
    }
  end

  private

  # @param quantities [Hash{#id => Integer}]
  # @return [Hash{String => Hash}]
  def quantity_fields(quantities)
    quantities.to_h { |record, quantity| [ record.id.to_s, { quantity: quantity.to_s } ] }
  end
end
