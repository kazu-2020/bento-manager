require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  fixtures :catalogs

  test "validations" do
    @subject = Catalog.new(name: "テスト弁当", kana: "テストベントウ", category: :bento)

    must validate_presence_of(:name)
    must validate_presence_of(:category)
    must validate_presence_of(:kana)
    must validate_uniqueness_of(:name).case_insensitive
    must allow_value("カレー").for(:kana)
    must allow_value("テストベントウ").for(:kana)
    wont allow_value("てすとべんとう").for(:kana)
    wont allow_value("テスト弁当").for(:kana)
    must define_enum_for(:category).with_values(bento: 0, side_menu: 1).validating
  end

  test "associations" do
    @subject = Catalog.new

    must have_one(:discontinuation).class_name("CatalogDiscontinuation").dependent(:restrict_with_error)
    must have_many(:prices).class_name("CatalogPrice").dependent(:restrict_with_error)
    must have_many(:pricing_rules).class_name("CatalogPricingRule").dependent(:restrict_with_error)
    must have_many(:daily_inventories).dependent(:restrict_with_error)
    must have_many(:sale_items).dependent(:restrict_with_error)
    must have_many(:additional_orders).dependent(:restrict_with_error)
  end

  test "新規作成時のデフォルトカテゴリは未設定である" do
    catalog = Catalog.new(name: "デフォルトテスト")
    assert_nil catalog.category
  end

  test "価格ルールのうち現在有効なものだけが取得される" do
    catalog = Catalog.create!(name: "active_pricing_rules テスト", kana: "アクティブプライシングルールステスト", category: :side_menu)

    past_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 2.months.ago,
      valid_until: 1.month.ago
    )

    current_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.week.ago,
      valid_until: nil
    )

    future_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.month.from_now,
      valid_until: nil
    )

    active_rules = catalog.active_pricing_rules

    assert_not_includes active_rules, past_rule, "期限切れのルールは含まれるべきでない"
    assert_includes active_rules, current_rule, "現在有効なルールは含まれるべき"
    assert_not_includes active_rules, future_rule, "未来のルールは含まれるべきでない"
  end

  test "指定した種類の現在有効な価格を取得できる" do
    catalog = Catalog.create!(name: "price_by_kind テスト", kana: "プライスバイカインドテスト", category: :side_menu)

    regular_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 250,
      effective_from: 1.day.ago,
      effective_until: nil
    )

    bundle_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :bundle,
      price: 150,
      effective_from: 1.day.ago,
      effective_until: nil
    )

    assert_equal regular_price, catalog.price_by_kind(:regular)
    assert_equal bundle_price, catalog.price_by_kind(:bundle)

    catalog_without_prices = Catalog.create!(name: "価格なしテスト", kana: "カカクナシテスト", category: :bento)
    assert_nil catalog_without_prices.price_by_kind(:regular)
  end

  test "提供終了した商品は販売可能な一覧から除外される" do
    available_catalog = Catalog.create!(name: "販売中弁当", kana: "ハンバイチュウベントウ", category: :bento)
    discontinued_catalog = Catalog.create!(name: "終了弁当", kana: "シュウリョウベントウ", category: :bento)

    CatalogDiscontinuation.create!(
      catalog: discontinued_catalog,
      discontinued_at: Time.current,
      reason: "販売終了"
    )

    assert discontinued_catalog.discontinued?
    assert_not available_catalog.discontinued?

    assert_includes Catalog.available, available_catalog
    assert_not_includes Catalog.available, discontinued_catalog
  end

  test "一覧は販売中を先に表示し、同じ状態ではカナ昇順で並ぶ" do
    available_b = Catalog.create!(name: "B弁当販売中", kana: "ビーベントウハンバイチュウ", category: :bento)
    available_a = Catalog.create!(name: "A弁当販売中", kana: "エーベントウハンバイチュウ", category: :bento)
    discontinued_b = Catalog.create!(name: "B弁当終了", kana: "ビーベントウシュウリョウ", category: :bento)
    discontinued_a = Catalog.create!(name: "A弁当終了", kana: "エーベントウシュウリョウ", category: :bento)

    CatalogDiscontinuation.create!(catalog: discontinued_b, discontinued_at: Time.current, reason: "終了")
    CatalogDiscontinuation.create!(catalog: discontinued_a, discontinued_at: Time.current, reason: "終了")

    result = Catalog.where(id: [ available_a, available_b, discontinued_a, discontinued_b ]).display_order.to_a

    assert_equal [ available_a, available_b, discontinued_a, discontinued_b ], result
  end

  test "カテゴリ別一覧は弁当を先に表示し、同じカテゴリ内ではカナ昇順で並ぶ" do
    bento_b = Catalog.create!(name: "B弁当", kana: "ビーベントウ", category: :bento)
    bento_a = Catalog.create!(name: "A弁当", kana: "エーベントウ", category: :bento)
    side_b = Catalog.create!(name: "Bサイド", kana: "ビーサイド", category: :side_menu)
    side_a = Catalog.create!(name: "Aサイド", kana: "エーサイド", category: :side_menu)

    result = Catalog.where(id: [ bento_a, bento_b, side_a, side_b ]).category_order.to_a

    assert_equal [ bento_a, bento_b, side_a, side_b ], result
  end

  test "物理削除は禁止されている" do
    catalog = catalogs(:daily_bento_a)
    initial_count = Catalog.count

    result = catalog.destroy

    assert_not result, "destroy は false を返すべき"
    assert_equal initial_count, Catalog.count, "レコード数は変わらないべき"
    assert catalog.persisted?, "レコードは削除されていないべき"
  end
end
