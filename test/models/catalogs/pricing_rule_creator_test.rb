# frozen_string_literal: true

require "test_helper"

class Catalogs::PricingRuleCreatorTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_prices, :catalog_pricing_rules

  # ===== Task 42.1: クラス構造 =====

  test "target_catalog を受け取ってインスタンスを作成できる" do
    catalog = catalogs(:salad)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    assert_kind_of Catalogs::PricingRuleCreator, creator
  end

  # ===== Task 42.2: create メソッド =====

  test "create は今日時点で有効な価格が存在する場合にルールを作成する" do
    # salad には bundle 価格が設定されている
    catalog = catalogs(:salad)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    rule_params = {
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 2,
      valid_from: Date.current,
      valid_until: nil
    }

    assert_difference "CatalogPricingRule.count" do
      rule = creator.create(rule_params)
      assert_kind_of CatalogPricingRule, rule
      assert_equal catalog.id, rule.target_catalog_id
      assert_equal "bundle", rule.price_kind
      assert_equal 2, rule.max_per_trigger
    end
  end

  test "create は価格が存在しない場合に MissingPriceError を発生させる" do
    # miso_soup には価格が設定されていない
    catalog = catalogs(:miso_soup)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    rule_params = {
      price_kind: :regular,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current,
      valid_until: nil
    }

    error = assert_raises(Errors::MissingPriceError) do
      creator.create(rule_params)
    end

    assert_equal 1, error.missing_prices.length
    assert_equal "味噌汁", error.missing_prices.first[:catalog_name]
    assert_equal "regular", error.missing_prices.first[:price_kind]
    assert_match(/味噌汁/, error.message)
  end

  test "create は bundle 価格が存在しない場合に MissingPriceError を発生させる" do
    # daily_bento_a には bundle 価格が設定されていない
    catalog = catalogs(:daily_bento_a)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    rule_params = {
      price_kind: :bundle,
      trigger_category: :side_menu,
      max_per_trigger: 1,
      valid_from: Date.current,
      valid_until: nil
    }

    error = assert_raises(Errors::MissingPriceError) do
      creator.create(rule_params)
    end

    assert_equal "bundle", error.missing_prices.first[:price_kind]
  end

  test "create はバリデーションエラーの場合に RecordInvalid を発生させる" do
    catalog = catalogs(:salad)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    rule_params = {
      price_kind: :bundle,
      trigger_category: nil, # 必須項目が欠落
      max_per_trigger: 1,
      valid_from: Date.current
    }

    assert_raises(ActiveRecord::RecordInvalid) do
      creator.create(rule_params)
    end
  end

  test "create は将来の valid_from の場合は価格存在検証をスキップする" do
    # miso_soup には価格が設定されていない
    catalog = catalogs(:miso_soup)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    rule_params = {
      price_kind: :regular,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.month.from_now.to_date, # 将来の日付
      valid_until: nil
    }

    # 価格が存在しなくても、将来の valid_from なら作成できる
    assert_difference "CatalogPricingRule.count" do
      rule = creator.create(rule_params)
      assert_kind_of CatalogPricingRule, rule
    end
  end

  test "create は今日より前の valid_from でも今日時点で有効なら検証する" do
    # miso_soup には価格が設定されていない
    catalog = catalogs(:miso_soup)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    rule_params = {
      price_kind: :regular,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.week.ago.to_date, # 過去の日付だが有効
      valid_until: nil
    }

    # 過去の valid_from でも今日時点で有効なら検証される
    assert_raises(Errors::MissingPriceError) do
      creator.create(rule_params)
    end
  end

  test "create は今日より前に終了する valid_until の場合は価格存在検証をスキップする" do
    # miso_soup には価格が設定されていない
    catalog = catalogs(:miso_soup)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    rule_params = {
      price_kind: :regular,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.month.ago.to_date,
      valid_until: 1.week.ago.to_date # 既に終了
    }

    # 既に無効なルールなら価格検証をスキップ
    assert_difference "CatalogPricingRule.count" do
      rule = creator.create(rule_params)
      assert_kind_of CatalogPricingRule, rule
    end
  end

  # ===== Task 42.3: update メソッド =====

  test "update は今日時点で有効になるルールの価格存在を検証する" do
    rule = catalog_pricing_rules(:salad_bundle_by_bento)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: rule.target_catalog)

    # salad には bundle 価格が存在するので更新できる
    assert_no_difference "CatalogPricingRule.count" do
      updated_rule = creator.update(rule, max_per_trigger: 3)
      assert_equal 3, updated_rule.max_per_trigger
    end
  end

  test "update は将来のルールを更新する場合は価格存在検証をスキップする" do
    # 価格が存在しない miso_soup で、将来から有効なルールを作成
    catalog = catalogs(:miso_soup)
    rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :regular,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.month.from_now.to_date,
      valid_until: nil
    )

    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    # 将来のルールに valid_until を設定しても、今日時点では有効でないので検証不要
    updated_rule = creator.update(rule, valid_until: 2.months.from_now.to_date)
    assert_equal 2.months.from_now.to_date, updated_rule.valid_until
  end

  test "update は将来に有効化する場合は価格存在検証をスキップする" do
    # miso_soup には価格が設定されていない
    catalog = catalogs(:miso_soup)

    # 将来から有効なルールを作成
    rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :regular,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.month.from_now.to_date,
      valid_until: nil
    )

    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    # 将来のままなら更新可能
    updated_rule = creator.update(rule, max_per_trigger: 2)
    assert_equal 2, updated_rule.max_per_trigger
  end

  test "update は将来のルールを今日から有効にする場合は価格存在を検証する" do
    # miso_soup には価格が設定されていない
    catalog = catalogs(:miso_soup)

    # 将来から有効なルールを作成
    rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :regular,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.month.from_now.to_date,
      valid_until: nil
    )

    creator = Catalogs::PricingRuleCreator.new(target_catalog: catalog)

    # 今日から有効にすると価格検証が発生
    error = assert_raises(Errors::MissingPriceError) do
      creator.update(rule, valid_from: Date.current)
    end

    assert_equal "味噌汁", error.missing_prices.first[:catalog_name]
  end

  test "update は RecordInvalid を発生させる" do
    rule = catalog_pricing_rules(:salad_bundle_by_bento)
    creator = Catalogs::PricingRuleCreator.new(target_catalog: rule.target_catalog)

    assert_raises(ActiveRecord::RecordInvalid) do
      creator.update(rule, max_per_trigger: -1) # 無効な値
    end
  end
end
