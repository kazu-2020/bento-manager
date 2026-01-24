require "test_helper"

class CatalogPriceTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_prices

  # ===== バリデーションテスト =====

  test "catalog は必須" do
    price = CatalogPrice.new(catalog: nil, kind: :regular, price: 500, effective_from: Time.current)
    assert_not price.valid?
    assert_includes price.errors[:catalog], "を入力してください"
  end

  test "kind は必須" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(catalog: catalog, kind: nil, price: 500, effective_from: Time.current)
    assert_not price.valid?
    assert_includes price.errors[:kind], "を入力してください"
  end

  test "price は必須" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(catalog: catalog, kind: :regular, price: nil, effective_from: Time.current)
    assert_not price.valid?
    assert_includes price.errors[:price], "を入力してください"
  end

  test "price は 0 より大きい必要がある" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(catalog: catalog, kind: :regular, price: 0, effective_from: Time.current)
    assert_not price.valid?
    assert_includes price.errors[:price], "は0より大きい値にしてください"
  end

  test "price は負の値を許可しない" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(catalog: catalog, kind: :regular, price: -100, effective_from: Time.current)
    assert_not price.valid?
    assert_includes price.errors[:price], "は0より大きい値にしてください"
  end

  test "effective_from は必須" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: nil)
    assert_not price.valid?
    assert_includes price.errors[:effective_from], "を入力してください"
  end

  test "effective_until が effective_from より前の場合はエラー" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(
      catalog: catalog,
      kind: :regular,
      price: 500,
      effective_from: Time.current,
      effective_until: 1.day.ago
    )
    assert_not price.valid?
    assert_includes price.errors[:effective_until], "は適用開始日時より後の日時を指定してください"
  end

  test "effective_until が effective_from と同じ日時の場合はエラー" do
    now = Time.current
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(
      catalog: catalog,
      kind: :regular,
      price: 500,
      effective_from: now,
      effective_until: now
    )
    assert_not price.valid?
    assert_includes price.errors[:effective_until], "は適用開始日時より後の日時を指定してください"
  end

  test "effective_until が effective_from より後の場合は有効" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(
      catalog: catalog,
      kind: :regular,
      price: 500,
      effective_from: Time.current,
      effective_until: 1.day.from_now
    )
    assert price.valid?, "effective_until が effective_from より後なら有効: #{price.errors.full_messages.join(', ')}"
  end

  test "effective_until が nil の場合は有効（無期限）" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(
      catalog: catalog,
      kind: :regular,
      price: 500,
      effective_from: Time.current,
      effective_until: nil
    )
    assert price.valid?, "effective_until が nil なら有効: #{price.errors.full_messages.join(', ')}"
  end

  test "有効な属性で作成できる" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(
      catalog: catalog,
      kind: :regular,
      price: 550,
      effective_from: Time.current
    )
    assert price.valid?, "有効な属性で CatalogPrice を作成できるべき: #{price.errors.full_messages.join(', ')}"
  end

  # ===== Enum テスト =====

  test "kind enum は regular と bundle を持つ" do
    assert_equal 0, CatalogPrice.kinds[:regular]
    assert_equal 1, CatalogPrice.kinds[:bundle]
  end

  test "kind に無効な値を設定するとバリデーションエラー" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.new(catalog: catalog, kind: :invalid_kind, price: 500, effective_from: Time.current)
    assert_not price.valid?
    assert_includes price.errors[:kind], "は一覧にありません"
  end

  # ===== スコープテスト =====

  test "current スコープは有効期間内の価格のみ取得" do
    catalog = catalogs(:daily_bento_a)

    # 過去の価格（有効期限切れ）
    past_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 400,
      effective_from: 2.days.ago,
      effective_until: 1.day.ago
    )

    # 現在有効な価格
    current_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 500,
      effective_from: 1.day.ago,
      effective_until: nil
    )

    # 未来の価格（まだ有効でない）
    future_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 600,
      effective_from: 1.day.from_now,
      effective_until: nil
    )

    current_prices = CatalogPrice.current

    assert_not_includes current_prices, past_price, "期限切れの価格は含まれるべきでない"
    assert_includes current_prices, current_price, "現在有効な価格は含まれるべき"
    assert_not_includes current_prices, future_price, "未来の価格は含まれるべきでない"
  end

  test "by_kind スコープは指定した kind のみ取得" do
    catalog = catalogs(:salad)

    regular_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 250,
      effective_from: Time.current
    )

    bundle_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :bundle,
      price: 150,
      effective_from: Time.current
    )

    regular_prices = CatalogPrice.by_kind(:regular)
    bundle_prices = CatalogPrice.by_kind(:bundle)

    assert_includes regular_prices, regular_price
    assert_not_includes regular_prices, bundle_price
    assert_includes bundle_prices, bundle_price
    assert_not_includes bundle_prices, regular_price
  end

  # ===== クラスメソッドテスト =====

  test "price_by_kind は指定した kind の現在価格を取得" do
    catalog = catalogs(:daily_bento_b)

    # 現在有効な regular 価格
    regular_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 600,
      effective_from: 1.day.ago,
      effective_until: nil
    )

    # 現在有効な bundle 価格
    bundle_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :bundle,
      price: 500,
      effective_from: 1.day.ago,
      effective_until: nil
    )

    assert_equal regular_price, catalog.prices.price_by_kind(kind: :regular)
    assert_equal bundle_price, catalog.prices.price_by_kind(kind: :bundle)
  end

  test "price_by_kind は有効な価格がない場合 nil を返す" do
    catalog = catalogs(:discontinued_bento)
    assert_nil catalog.prices.price_by_kind(kind: :regular)
  end

  test "price_by_kind は指定した日時の価格を取得" do
    catalog = catalogs(:daily_bento_b)

    # 過去の価格（1週間前から昨日まで有効）
    past_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 500,
      effective_from: 1.week.ago,
      effective_until: 1.day.ago
    )

    # 現在有効な価格
    current_price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 600,
      effective_from: 1.day.ago,
      effective_until: nil
    )

    # at パラメータで過去の日時を指定
    assert_equal past_price, catalog.prices.price_by_kind(kind: :regular, at: 3.days.ago)
    assert_equal current_price, catalog.prices.price_by_kind(kind: :regular, at: Time.current)
  end

  # ===== create_with_history! テスト =====

  test "create_with_history! は新しい価格を作成する" do
    catalog = catalogs(:daily_bento_b)

    new_price = CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 700)

    assert new_price.persisted?
    assert_equal catalog, new_price.catalog
    assert_equal "regular", new_price.kind
    assert_equal 700, new_price.price
    assert_not_nil new_price.effective_from
    assert_nil new_price.effective_until
  end

  test "create_with_history! は既存価格があれば終了させる" do
    catalog = catalogs(:daily_bento_a)
    old_price = catalog_prices(:daily_bento_a_regular)
    assert_nil old_price.effective_until, "テスト前提: 既存価格は終了していない"

    new_price = CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 600)

    old_price.reload
    assert_not_nil old_price.effective_until, "既存価格に effective_until が設定されるべき"
    assert new_price.persisted?
    assert_equal 600, new_price.price
  end

  test "create_with_history! はバリデーションエラー時にロールバックする" do
    catalog = catalogs(:daily_bento_a)
    old_price = catalog_prices(:daily_bento_a_regular)

    assert_raises(ActiveRecord::RecordInvalid) do
      CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 0)
    end

    old_price.reload
    assert_nil old_price.effective_until, "ロールバックにより既存価格は変更されないべき"
  end

  # ===== アソシエーションテスト =====

  test "catalog との関連が正しく設定されている" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 550,
      effective_from: Time.current
    )

    assert_equal catalog, price.catalog
  end
end
