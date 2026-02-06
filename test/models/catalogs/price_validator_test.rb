# frozen_string_literal: true

require "test_helper"

class Catalogs::PriceValidatorTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_prices, :catalog_pricing_rules

  test "指定した商品と種別の価格の存在確認と取得ができる" do
    validator = Catalogs::PriceValidator.new

    assert validator.price_exists?(catalogs(:daily_bento_a), :regular)
    assert_not validator.price_exists?(catalogs(:miso_soup), :regular)
    assert validator.price_exists?(catalogs(:salad), :bundle)
    assert_not validator.price_exists?(catalogs(:daily_bento_a), :bundle)

    price = validator.find_price(catalogs(:daily_bento_a), :regular)
    assert_kind_of CatalogPrice, price
    assert_equal 550, price.price

    assert_nil validator.find_price(catalogs(:miso_soup), :regular)

    found = validator.find_price!(catalogs(:daily_bento_a), :regular)
    assert_equal 550, found.price
  end

  test "価格が存在しない商品で取得を強制するとエラーになる" do
    validator = Catalogs::PriceValidator.new

    error = assert_raises(Errors::MissingPriceError) do
      validator.find_price!(catalogs(:miso_soup), :regular)
    end

    assert_equal 1, error.missing_prices.length
    assert_equal "味噌汁", error.missing_prices.first[:catalog_name]
    assert_equal "regular", error.missing_prices.first[:price_kind]
  end

  test "基準日を指定して過去時点の価格を検証できる" do
    validator = Catalogs::PriceValidator.new(at: 2.months.ago.to_date)

    assert_not validator.price_exists?(catalogs(:daily_bento_a), :regular)
    assert_nil validator.find_price(catalogs(:daily_bento_a), :regular)
  end

  test "価格設定に不備がある商品を一覧できる" do
    validator = Catalogs::PriceValidator.new
    result = validator.catalogs_with_missing_prices

    miso_soup = catalogs(:miso_soup)
    missing_miso_soup = result.find { |r| r[:catalog].id == miso_soup.id }
    assert_not_nil missing_miso_soup
    assert_includes missing_miso_soup[:missing_kinds], "regular"

    assert_not result.any? { |r| r[:catalog].id == catalogs(:daily_bento_a).id }
    assert_not result.any? { |r| r[:catalog].id == catalogs(:salad).id }
  end

  test "提供終了した商品は価格不備一覧に含まれない" do
    discontinued = catalogs(:discontinued_bento)
    CatalogDiscontinuation.create!(catalog: discontinued, discontinued_at: 1.day.ago, reason: "テスト用提供終了")

    result = Catalogs::PriceValidator.new.catalogs_with_missing_prices

    assert_not result.any? { |r| r[:catalog].id == discontinued.id }
  end

  test "価格ルールが参照するセット価格の欠落を検出できる" do
    miso_soup = catalogs(:miso_soup)
    CatalogPricingRule.create!(
      target_catalog: miso_soup,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.month.ago.to_date
    )

    result = Catalogs::PriceValidator.new.catalogs_with_missing_prices

    missing = result.find { |r| r[:catalog].id == miso_soup.id }
    assert_not_nil missing
    assert_includes missing[:missing_kinds], "bundle"
  end
end
