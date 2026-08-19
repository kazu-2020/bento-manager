require "test_helper"

class ValidPeriodTest < ActiveSupport::TestCase
  test "有効期間の判定は開始日と終了日の両方を含み、終了日が未設定なら以降ずっと有効" do
    today = Date.current

    # discounts の (discountable_type, discountable_id) は unique なので、
    # 既存フィクスチャのクーポンは使い回せない
    same_day = Discount.create!(discountable: Coupon.create!(amount_per_unit: 50), name: "1日だけの割引", valid_from: today, valid_until: today)

    assert same_day.active_at?(today)
    assert_not same_day.active_at?(today + 1)

    # SQL 版と Ruby 版で答えが割れないこと
    assert_includes Discount.active_at(today), same_day
    assert_not_includes Discount.active_at(today + 1), same_day

    open_ended = Discount.new(valid_from: today, valid_until: nil)

    assert_not open_ended.active_at?(today - 1)
    assert open_ended.active_at?(today + 365)

    assert_not Discount.new(valid_from: nil).active_at?(today)
  end
end
