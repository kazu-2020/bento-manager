# 差額精算フォームのパラメータ組み立てヘルパー
#
# 確定用（refund）と Ghost Form 用（ghost_refund）で名前空間だけが異なり、
# 中身の形は同じ。名前空間は呼び出し側が与える。
module RefundParamsHelper
  # 修正後の数量をフォームのパラメータ形式に変換する
  #
  # クーポンは指定しなかったものも 0 枚として明示的に含める。空ハッシュは
  # 送信ボディから消えてしまい、RefundForm が「指定なし = 元の販売のクーポンを
  # 引き継ぐ」経路に落ちるため。実際のフォームも画面に出ている全クーポンの
  # hidden field を送るので、そちらの挙動とも揃う。
  #
  # @param corrected [Hash{Catalog => Integer}] 修正後の商品数量
  # @param coupon [Hash{Discount => Integer}] 修正後のクーポン枚数（未指定は 0 枚）
  # @return [Hash] { corrected: { "<id>" => { quantity: "<n>" } }, coupon: {...} }
  def refund_quantity_params(corrected: {}, coupon: {})
    { corrected: quantity_fields(corrected), coupon: quantity_fields(all_coupon_quantities(coupon)) }
  end

  def quantity_fields(quantities)
    quantities.to_h { |record, quantity| [ record.id.to_s, { quantity: quantity.to_s } ] }
  end

  # 画面に出る全クーポンを 0 枚で埋め、指定された枚数で上書きする
  def all_coupon_quantities(coupon)
    Discount.active_at(Date.current).index_with(0).merge(coupon)
  end
end
