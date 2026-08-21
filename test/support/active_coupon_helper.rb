# frozen_string_literal: true

# 有効なクーポンを作るヘルパー
#
# 母集合を増やして問い合わせ本数を比べるテストと、id の順序に依存できない適用順の
# テストが、どちらも当日有効なクーポンを作る。作り方が割れないようここに置く
module ActiveCouponHelper
  # 当日有効なクーポンを 1 種類作る
  #
  # @param amount [Integer] 1 枚あたりの割引額
  # @param name [String, nil] 割引の名前。省略すると割引額から作る
  # @return [Discount]
  def create_active_coupon(amount: 80, name: nil)
    Discount.create!(
      name: name || "#{amount}円割引クーポン",
      valid_from: 1.month.ago.to_date,
      discountable: Coupon.new(amount_per_unit: amount)
    )
  end
end
