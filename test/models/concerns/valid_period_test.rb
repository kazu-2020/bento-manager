require "test_helper"

class ValidPeriodTest < ActiveSupport::TestCase
  fixtures :catalogs

  test "有効開始日が未設定のレコードはどの日付でも有効ではない" do
    rule = CatalogPricingRule.new(target_catalog: catalogs(:salad), price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: nil)

    assert_not rule.active_at?(Date.current)
  end

  test "有効期間の判定は開始日と終了日の両方を含み、終了日が未設定なら以降ずっと有効" do
    coupon = Coupon.create!(amount_per_unit: 50)
    today = Date.current

    limited = Discount.new(discountable: coupon, name: "テスト", valid_from: today, valid_until: today + 1)

    assert_not limited.active_at?(today - 1)
    assert limited.active_at?(today)
    assert limited.active_at?(today + 1)
    assert_not limited.active_at?(today + 2)

    open_ended = Discount.new(discountable: coupon, name: "テスト", valid_from: today, valid_until: nil)

    assert_not open_ended.active_at?(today - 1)
    assert open_ended.active_at?(today)
    assert open_ended.active_at?(today + 365)
  end

  test "Ruby 版の判定は active_at スコープと同じレコードを有効と見なす" do
    catalog = catalogs(:salad)
    today = Date.current

    same_day = CatalogPricingRule.create!(target_catalog: catalog, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: today, valid_until: today)

    assert_includes CatalogPricingRule.active_at(today), same_day
    assert same_day.active_at?(today)

    assert_not_includes CatalogPricingRule.active_at(today + 1), same_day
    assert_not same_day.active_at?(today + 1)
  end
end
