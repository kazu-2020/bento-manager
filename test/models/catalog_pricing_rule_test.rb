require "test_helper"

class CatalogPricingRuleTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_pricing_rules

  # ===== バリデーションテスト =====

  test "target_catalog は必須" do
    rule = CatalogPricingRule.new(
      target_catalog: nil,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )
    assert_not rule.valid?
    assert_includes rule.errors[:target_catalog], "を入力してください"
  end

  test "price_kind は必須" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: nil,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )
    assert_not rule.valid?
    assert_includes rule.errors[:price_kind], "を入力してください"
  end

  test "price_kind は regular または bundle のみ許可" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :invalid_kind,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )
    assert_not rule.valid?
    assert_includes rule.errors[:price_kind], "は一覧にありません"
  end

  test "trigger_category は必須" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: nil,
      max_per_trigger: 1,
      valid_from: Date.current
    )
    assert_not rule.valid?
    assert_includes rule.errors[:trigger_category], "を入力してください"
  end

  test "trigger_category は bento または side_menu のみ許可" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :invalid_category,
      max_per_trigger: 1,
      valid_from: Date.current
    )
    assert_not rule.valid?
    assert_includes rule.errors[:trigger_category], "は一覧にありません"
  end

  test "max_per_trigger は 0 以上である必要がある" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: -1,
      valid_from: Date.current
    )
    assert_not rule.valid?
    assert_includes rule.errors[:max_per_trigger], "は0以上の値にしてください"
  end

  test "valid_from は必須" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: nil
    )
    assert_not rule.valid?
    assert_includes rule.errors[:valid_from], "を入力してください"
  end

  test "valid_until が valid_from より前の場合はエラー" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current,
      valid_until: 1.day.ago.to_date
    )
    assert_not rule.valid?
    assert_includes rule.errors[:valid_until], "は有効開始日より後の日付を指定してください"
  end

  test "valid_until が valid_from と同じ日の場合はエラー" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current,
      valid_until: Date.current
    )
    assert_not rule.valid?
    assert_includes rule.errors[:valid_until], "は有効開始日より後の日付を指定してください"
  end

  test "valid_until が valid_from より後の場合は有効" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current,
      valid_until: 1.day.from_now.to_date
    )
    assert rule.valid?, "valid_until が valid_from より後なら有効: #{rule.errors.full_messages.join(', ')}"
  end

  test "valid_until が nil の場合は有効（無期限）" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current,
      valid_until: nil
    )
    assert rule.valid?, "valid_until が nil なら有効: #{rule.errors.full_messages.join(', ')}"
  end

  test "有効な属性で作成できる" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.new(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )
    assert rule.valid?, "有効な属性で CatalogPricingRule を作成できるべき: #{rule.errors.full_messages.join(', ')}"
  end

  # ===== スコープテスト =====

  test "active スコープは有効期間内のルールのみ取得" do
    catalog = catalogs(:salad)

    # 過去のルール（有効期限切れ）
    past_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 2.days.ago.to_date,
      valid_until: 1.day.ago.to_date
    )

    # 現在有効なルール
    current_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.day.ago.to_date,
      valid_until: nil
    )

    # 未来のルール（まだ有効でない）
    future_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.day.from_now.to_date,
      valid_until: nil
    )

    active_rules = CatalogPricingRule.active

    assert_not_includes active_rules, past_rule, "期限切れのルールは含まれるべきでない"
    assert_includes active_rules, current_rule, "現在有効なルールは含まれるべき"
    assert_not_includes active_rules, future_rule, "未来のルールは含まれるべきでない"
  end

  test "for_target スコープは指定した target_catalog_id のルールのみ取得" do
    salad = catalogs(:salad)
    bento_a = catalogs(:daily_bento_a)

    salad_rule = CatalogPricingRule.create!(
      target_catalog: salad,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    bento_rule = CatalogPricingRule.create!(
      target_catalog: bento_a,
      price_kind: :regular,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    salad_rules = CatalogPricingRule.for_target(salad.id)

    assert_includes salad_rules, salad_rule
    assert_not_includes salad_rules, bento_rule
  end

  test "triggered_by スコープは指定した trigger_category のルールのみ取得" do
    catalog = catalogs(:salad)

    bento_triggered_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    side_menu_triggered_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :regular,
      trigger_category: :side_menu,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    bento_triggered_rules = CatalogPricingRule.triggered_by(:bento)

    assert_includes bento_triggered_rules, bento_triggered_rule
    assert_not_includes bento_triggered_rules, side_menu_triggered_rule
  end

  # ===== ビジネスロジックメソッドテスト =====

  test "applicable? はカート内に trigger_category があれば true を返す" do
    salad = catalogs(:salad)
    bento_a = catalogs(:daily_bento_a)

    rule = CatalogPricingRule.create!(
      target_catalog: salad,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    cart_items = [
      { catalog: bento_a, quantity: 1 },
      { catalog: salad, quantity: 2 }
    ]

    assert rule.applicable?(cart_items), "弁当がカートにあればルールは適用可能"
  end

  test "applicable? はカート内に trigger_category がなければ false を返す" do
    salad = catalogs(:salad)

    rule = CatalogPricingRule.create!(
      target_catalog: salad,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    cart_items = [
      { catalog: salad, quantity: 2 }
    ]

    assert_not rule.applicable?(cart_items), "弁当がカートになければルールは適用不可"
  end

  test "max_applicable_quantity は trigger_category の数量 × max_per_trigger を返す" do
    salad = catalogs(:salad)
    bento_a = catalogs(:daily_bento_a)
    bento_b = catalogs(:daily_bento_b)

    rule = CatalogPricingRule.create!(
      target_catalog: salad,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    # 弁当2個（bento_a: 1個, bento_b: 1個）の場合、サラダは最大2個までセット価格
    cart_items = [
      { catalog: bento_a, quantity: 1 },
      { catalog: bento_b, quantity: 1 },
      { catalog: salad, quantity: 5 }
    ]

    assert_equal 2, rule.max_applicable_quantity(cart_items)
  end

  test "max_applicable_quantity は trigger_category がなければ 0 を返す" do
    salad = catalogs(:salad)

    rule = CatalogPricingRule.create!(
      target_catalog: salad,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    cart_items = [
      { catalog: salad, quantity: 3 }
    ]

    assert_equal 0, rule.max_applicable_quantity(cart_items)
  end

  test "max_applicable_quantity は quantity を考慮して計算する" do
    salad = catalogs(:salad)
    bento_a = catalogs(:daily_bento_a)

    rule = CatalogPricingRule.create!(
      target_catalog: salad,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    # 弁当3個の場合、サラダは最大3個までセット価格
    cart_items = [
      { catalog: bento_a, quantity: 3 },
      { catalog: salad, quantity: 5 }
    ]

    assert_equal 3, rule.max_applicable_quantity(cart_items)
  end

  # ===== アソシエーションテスト =====

  test "target_catalog との関連が正しく設定されている" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: Date.current
    )

    assert_equal catalog, rule.target_catalog
  end
end
