# frozen_string_literal: true

require "test_helper"

class Catalogs::PriceValidatorTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_prices, :catalog_pricing_rules

  # ===== Task 41.1: price_exists? =====

  test "price_exists? は指定したカタログに指定した種別の有効な価格が存在する場合に true を返す" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:daily_bento_a)

    assert validator.price_exists?(catalog, :regular)
  end

  test "price_exists? は指定したカタログに指定した種別の価格が存在しない場合に false を返す" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:miso_soup)

    assert_not validator.price_exists?(catalog, :regular)
  end

  test "price_exists? は bundle 価格が存在する場合に true を返す" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:salad)

    assert validator.price_exists?(catalog, :bundle)
  end

  test "price_exists? は bundle 価格が存在しない場合に false を返す" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:daily_bento_a)

    assert_not validator.price_exists?(catalog, :bundle)
  end

  test "price_exists? は基準日を指定できる" do
    validator = Catalogs::PriceValidator.new(at: 2.months.ago.to_date)
    catalog = catalogs(:daily_bento_a)

    # フィクスチャの価格は 1.month.ago から有効なので、2.months.ago では存在しない
    assert_not validator.price_exists?(catalog, :regular)
  end

  test "price_exists? はデフォルトで今日の日付を使用する" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:daily_bento_a)

    assert_equal Date.current, validator.at
    assert validator.price_exists?(catalog, :regular)
  end

  # ===== Task 41.2: find_price / find_price! =====

  test "find_price は指定したカタログと種別の価格を返す" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:daily_bento_a)

    price = validator.find_price(catalog, :regular)

    assert_kind_of CatalogPrice, price
    assert_equal 550, price.price
  end

  test "find_price は価格が存在しない場合に nil を返す" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:miso_soup)

    price = validator.find_price(catalog, :regular)

    assert_nil price
  end

  test "find_price! は指定したカタログと種別の価格を返す" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:daily_bento_a)

    price = validator.find_price!(catalog, :regular)

    assert_kind_of CatalogPrice, price
    assert_equal 550, price.price
  end

  test "find_price! は価格が存在しない場合に MissingPriceError を発生させる" do
    validator = Catalogs::PriceValidator.new
    catalog = catalogs(:miso_soup)

    error = assert_raises(Catalogs::PriceValidator::MissingPriceError) do
      validator.find_price!(catalog, :regular)
    end

    assert_equal "味噌汁", error.catalog_name
    assert_equal "regular", error.price_kind
    assert_match(/味噌汁/, error.message)
    assert_match(/regular/, error.message)
  end

  # ===== Task 41.3: catalogs_with_missing_prices =====

  test "catalogs_with_missing_prices は通常価格が設定されていない商品を返す" do
    validator = Catalogs::PriceValidator.new

    result = validator.catalogs_with_missing_prices

    # miso_soup には価格が設定されていない
    miso_soup = catalogs(:miso_soup)
    missing_miso_soup = result.find { |r| r[:catalog].id == miso_soup.id }

    assert_not_nil missing_miso_soup, "味噌汁が結果に含まれていません"
    assert_includes missing_miso_soup[:missing_kinds], "regular"
  end

  test "catalogs_with_missing_prices はすべての価格が設定されている商品を含まない" do
    validator = Catalogs::PriceValidator.new

    result = validator.catalogs_with_missing_prices

    # daily_bento_a と salad には価格が設定されている
    daily_bento_a = catalogs(:daily_bento_a)
    salad = catalogs(:salad)

    assert_not result.any? { |r| r[:catalog].id == daily_bento_a.id }, "日替わり弁当Aが結果に含まれています"
    assert_not result.any? { |r| r[:catalog].id == salad.id }, "サラダが結果に含まれています"
  end

  test "catalogs_with_missing_prices は提供終了した商品を含まない" do
    validator = Catalogs::PriceValidator.new
    # discontinued_bento は提供終了しているが、CatalogDiscontinuation がフィクスチャにないため、
    # テストでは提供終了状態を作成する必要がある
    discontinued = catalogs(:discontinued_bento)
    CatalogDiscontinuation.create!(catalog: discontinued, discontinued_at: 1.day.ago, reason: "テスト用提供終了")

    result = validator.catalogs_with_missing_prices

    assert_not result.any? { |r| r[:catalog].id == discontinued.id }, "提供終了した商品が結果に含まれています"
  end

  test "catalogs_with_missing_prices は価格ルールが参照する bundle 価格の欠落を検出する" do
    validator = Catalogs::PriceValidator.new
    # miso_soup に bundle 価格を要求する価格ルールを作成
    miso_soup = catalogs(:miso_soup)
    CatalogPricingRule.create!(
      target_catalog: miso_soup,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.month.ago.to_date,
      valid_until: nil
    )

    result = validator.catalogs_with_missing_prices

    missing_miso_soup = result.find { |r| r[:catalog].id == miso_soup.id }
    assert_not_nil missing_miso_soup, "味噌汁が結果に含まれていません"
    assert_includes missing_miso_soup[:missing_kinds], "bundle"
  end
end
