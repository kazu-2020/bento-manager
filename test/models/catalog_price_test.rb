require "test_helper"

class CatalogPriceTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_prices

  test "validations" do
    @subject = CatalogPrice.new(
      catalog: catalogs(:daily_bento_a),
      kind: :regular,
      price: 500,
      effective_from: Time.current
    )

    must validate_presence_of(:kind)
    must validate_presence_of(:price)
    must validate_numericality_of(:price).is_greater_than(0)
    must validate_presence_of(:effective_from)
    must define_enum_for(:kind).with_values(regular: 0, bundle: 1).validating
  end

  test "associations" do
    @subject = CatalogPrice.new

    must belong_to(:catalog)
    must have_many(:sale_items).dependent(:restrict_with_error)
  end

  test "有効期限の終了日時は開始日時より後でなければならない" do
    catalog = catalogs(:daily_bento_a)
    now = Time.current

    before_start = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: now, effective_until: 1.day.ago)
    assert_not before_start.valid?
    assert_includes before_start.errors[:effective_until], "は適用開始日時より後の日時を指定してください"

    same_time = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: now, effective_until: now)
    assert_not same_time.valid?

    after_start = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: now, effective_until: 1.day.from_now)
    assert after_start.valid?

    no_end = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: now, effective_until: nil)
    assert no_end.valid?
  end

  test "有効期間内の価格のみが取得される" do
    catalog = catalogs(:daily_bento_a)

    past_price = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 400, effective_from: 2.days.ago, effective_until: 1.day.ago)
    current_price = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 500, effective_from: 1.day.ago, effective_until: nil)
    future_price = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 600, effective_from: 1.day.from_now, effective_until: nil)

    result = CatalogPrice.current

    assert_includes result, current_price
    assert_not_includes result, past_price
    assert_not_includes result, future_price
  end

  test "指定した種別と日時の有効な価格を取得できる" do
    catalog = catalogs(:daily_bento_b)

    past_price = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 500, effective_from: 1.week.ago, effective_until: 1.day.ago)
    current_regular = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 600, effective_from: 1.day.ago, effective_until: nil)
    current_bundle = CatalogPrice.create!(catalog: catalog, kind: :bundle, price: 500, effective_from: 1.day.ago, effective_until: nil)

    assert_equal current_regular, catalog.prices.price_by_kind(kind: :regular)
    assert_equal current_bundle, catalog.prices.price_by_kind(kind: :bundle)
    assert_equal past_price, catalog.prices.price_by_kind(kind: :regular, at: 3.days.ago)

    empty_catalog = catalogs(:discontinued_bento)
    assert_nil empty_catalog.prices.price_by_kind(kind: :regular)
  end

  test "新しい価格を設定すると既存の価格が終了する" do
    catalog = catalogs(:daily_bento_a)
    old_price = catalog_prices(:daily_bento_a_regular)
    assert_nil old_price.effective_until

    new_price = CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 600)

    assert new_price.persisted?
    assert_equal 600, new_price.price
    assert_nil new_price.effective_until

    old_price.reload
    assert_not_nil old_price.effective_until
  end

  test "価格設定が不正な場合は既存の価格も変更されない" do
    catalog = catalogs(:daily_bento_a)
    old_price = catalog_prices(:daily_bento_a_regular)

    assert_raises(ActiveRecord::RecordInvalid) do
      CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 0)
    end

    old_price.reload
    assert_nil old_price.effective_until
  end
end
