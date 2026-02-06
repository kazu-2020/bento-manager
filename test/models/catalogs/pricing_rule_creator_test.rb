# frozen_string_literal: true

require "test_helper"

class Catalogs::PricingRuleCreatorTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_prices, :catalog_pricing_rules

  test "有効な価格が存在する商品に価格ルールを作成できる" do
    catalog = catalogs(:salad)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    assert_difference "CatalogPricingRule.count" do
      rule = creator.create(
        price_kind: :bundle, trigger_category: :bento,
        max_per_trigger: 2, valid_from: Date.current
      )

      assert_equal catalog.id, rule.target_catalog_id
      assert_equal "bundle", rule.price_kind
      assert_equal 2, rule.max_per_trigger
    end
  end

  test "価格が存在しない商品にルールを作成するとエラーになる" do
    catalog = catalogs(:miso_soup)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    error = assert_raises(Errors::MissingPriceError) do
      creator.create(price_kind: :regular, trigger_category: :bento, max_per_trigger: 1, valid_from: Date.current)
    end
    assert_equal "味噌汁", error.missing_prices.first[:catalog_name]

    error = assert_raises(Errors::MissingPriceError) do
      Catalogs::PricingRuleCreator.new(target_catalog: catalogs(:daily_bento_a))
        .create(price_kind: :bundle, trigger_category: :side_menu, max_per_trigger: 1, valid_from: Date.current)
    end
    assert_equal "bundle", error.missing_prices.first[:price_kind]

    assert_raises(ActiveRecord::RecordInvalid) do
      Catalogs::PricingRuleCreator.new(target_catalog: catalogs(:salad))
        .create(price_kind: :bundle, trigger_category: nil, max_per_trigger: 1, valid_from: Date.current)
    end
  end

  test "将来や過去に終了したルールは価格検証をスキップする" do
    catalog = catalogs(:miso_soup)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    assert_difference "CatalogPricingRule.count", 2 do
      rule = creator.create(price_kind: :regular, trigger_category: :bento, max_per_trigger: 1, valid_from: 1.month.from_now.to_date)
      assert_kind_of CatalogPricingRule, rule

      rule2 = creator.create(price_kind: :regular, trigger_category: :bento, max_per_trigger: 1, valid_from: 1.month.ago.to_date, valid_until: 1.week.ago.to_date)
      assert_kind_of CatalogPricingRule, rule2
    end

    assert_raises(Errors::MissingPriceError) do
      creator.create(price_kind: :regular, trigger_category: :bento, max_per_trigger: 1, valid_from: 1.week.ago.to_date)
    end
  end

  test "既存ルールを更新でき有効期間の変更で価格検証が発生する" do
    rule = catalog_pricing_rules(:salad_bundle_by_bento)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: rule.target_catalog)

    updated = creator.update(rule, max_per_trigger: 3)
    assert_equal 3, updated.max_per_trigger

    assert_raises(ActiveRecord::RecordInvalid) do
      creator.update(rule, max_per_trigger: -1)
    end
  end

  test "将来のルールを今日から有効にすると価格検証が発生する" do
    catalog = catalogs(:miso_soup)
    rule = CatalogPricingRule.create!(
      target_catalog: catalog, price_kind: :regular, trigger_category: :bento,
      max_per_trigger: 1, valid_from: 1.month.from_now.to_date
    )
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    updated = creator.update(rule, max_per_trigger: 2)
    assert_equal 2, updated.max_per_trigger

    error = assert_raises(Errors::MissingPriceError) do
      creator.update(rule, valid_from: Date.current)
    end
    assert_equal "味噌汁", error.missing_prices.first[:catalog_name]
  end
end
