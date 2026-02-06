require "test_helper"

class CatalogPricingRuleTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_pricing_rules

  test "validations" do
    @subject = CatalogPricingRule.new(
      target_catalog: catalogs(:salad),
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    must validate_presence_of(:price_kind)
    must validate_presence_of(:trigger_category)
    must validate_presence_of(:max_per_trigger)
    must validate_numericality_of(:max_per_trigger).is_greater_than_or_equal_to(0)
    must validate_presence_of(:valid_from)
    must define_enum_for(:price_kind).with_values(regular: 0, bundle: 1).validating
    must define_enum_for(:trigger_category).with_values(bento: 0, side_menu: 1).validating.with_prefix(:triggered_by)
  end

  test "associations" do
    @subject = CatalogPricingRule.new

    must belong_to(:target_catalog).class_name("Catalog")
  end

  test "有効期間の終了日は開始日より後でなければならない" do
    catalog = catalogs(:salad)
    today = Date.current

    before_start = CatalogPricingRule.new(target_catalog: catalog, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: today, valid_until: 1.day.ago.to_date)
    assert_not before_start.valid?
    assert_includes before_start.errors[:valid_until], "は有効開始日より後の日付を指定してください"

    same_day = CatalogPricingRule.new(target_catalog: catalog, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: today, valid_until: today)
    assert_not same_day.valid?

    after_start = CatalogPricingRule.new(target_catalog: catalog, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: today, valid_until: 1.day.from_now.to_date)
    assert after_start.valid?

    no_end = CatalogPricingRule.new(target_catalog: catalog, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: today, valid_until: nil)
    assert no_end.valid?
  end

  test "有効期間内のルールのみが取得される" do
    catalog = catalogs(:salad)

    past_rule = CatalogPricingRule.create!(target_catalog: catalog, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: 2.days.ago.to_date, valid_until: 1.day.ago.to_date)
    current_rule = CatalogPricingRule.create!(target_catalog: catalog, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: 1.day.ago.to_date, valid_until: nil)
    future_rule = CatalogPricingRule.create!(target_catalog: catalog, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: 1.day.from_now.to_date, valid_until: nil)

    result = CatalogPricingRule.active

    assert_includes result, current_rule
    assert_not_includes result, past_rule
    assert_not_includes result, future_rule
  end

  test "カート内にトリガーカテゴリがある場合のみ適用可能である" do
    salad = catalogs(:salad)
    bento = catalogs(:daily_bento_a)

    rule = CatalogPricingRule.create!(target_catalog: salad, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: Date.current)

    assert rule.applicable?([ { catalog: bento, quantity: 1 }, { catalog: salad, quantity: 2 } ])
    assert_not rule.applicable?([ { catalog: salad, quantity: 2 } ])
  end

  test "適用上限はトリガーカテゴリの合計個数に連動する" do
    salad = catalogs(:salad)
    bento_a = catalogs(:daily_bento_a)
    bento_b = catalogs(:daily_bento_b)

    rule = CatalogPricingRule.create!(target_catalog: salad, price_kind: :bundle, trigger_category: :bento, max_per_trigger: 1, valid_from: Date.current)

    assert_equal 2, rule.max_applicable_quantity([ { catalog: bento_a, quantity: 1 }, { catalog: bento_b, quantity: 1 }, { catalog: salad, quantity: 5 } ])
    assert_equal 3, rule.max_applicable_quantity([ { catalog: bento_a, quantity: 3 }, { catalog: salad, quantity: 5 } ])
    assert_equal 0, rule.max_applicable_quantity([ { catalog: salad, quantity: 3 } ])
  end
end
