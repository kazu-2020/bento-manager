require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  # ===== バリデーションテスト =====

  test "name は必須" do
    catalog = Catalog.new(name: nil, category: :bento)
    assert_not catalog.valid?
    assert_includes catalog.errors[:name], "を入力してください"
  end

  test "category は必須" do
    catalog = Catalog.new(name: "テスト弁当", category: nil)
    assert_not catalog.valid?
    assert_includes catalog.errors[:category], "を入力してください"
  end

  test "有効な属性で作成できる" do
    catalog = Catalog.new(name: "新規テスト弁当", category: :bento, description: "本日のおすすめ弁当")
    assert catalog.valid?, "有効な属性で Catalog を作成できるべき: #{catalog.errors.full_messages.join(', ')}"
  end

  # ===== Enum テスト =====

  test "category enum は bento と side_menu を持つ" do
    assert_equal 0, Catalog.categories[:bento]
    assert_equal 1, Catalog.categories[:side_menu]
  end

  test "category に無効な値を設定するとバリデーションエラー" do
    catalog = Catalog.new(name: "テスト商品", category: :invalid_category)
    assert_not catalog.valid?
    assert_includes catalog.errors[:category], "は一覧にありません"
  end

  # ===== Enum スコープテスト =====

  test "bento スコープは bento カテゴリのみ取得" do
    bento = Catalog.create!(name: "テスト弁当", category: :bento)
    side_menu = Catalog.create!(name: "テストサラダ", category: :side_menu)

    assert_includes Catalog.bento, bento
    assert_not_includes Catalog.bento, side_menu
  end

  test "side_menu スコープは side_menu カテゴリのみ取得" do
    bento = Catalog.create!(name: "テスト弁当B", category: :bento)
    side_menu = Catalog.create!(name: "テストサラダB", category: :side_menu)

    assert_includes Catalog.side_menu, side_menu
    assert_not_includes Catalog.side_menu, bento
  end

  # ===== Enum 更新メソッドテスト =====

  test "bento! で category を bento に変更" do
    catalog = Catalog.create!(name: "変更テスト商品", category: :side_menu)
    catalog.bento!
    assert catalog.bento?
  end

  test "side_menu! で category を side_menu に変更" do
    catalog = Catalog.create!(name: "変更テスト商品2", category: :bento)
    catalog.side_menu!
    assert catalog.side_menu?
  end

  # ===== デフォルト値テスト =====

  test "新規作成時のデフォルト category は設定されない" do
    catalog = Catalog.new(name: "デフォルトテスト")
    assert_nil catalog.category
  end

  # ===== ユニーク制約テスト（Task 4.5 追加） =====

  test "name のユニーク制約（大文字小文字を区別しない）" do
    Catalog.create!(name: "テスト弁当X", category: :bento)

    duplicate = Catalog.new(name: "テスト弁当X", category: :bento)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "はすでに存在します"
  end

  test "name のユニーク制約は大文字小文字を区別しない" do
    Catalog.create!(name: "Test Bento", category: :bento)

    duplicate = Catalog.new(name: "test bento", category: :bento)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "はすでに存在します"
  end

  # ===== アソシエーションテスト（Task 4.5 追加） =====

  test "prices との関連が正しく設定されている" do
    catalog = catalogs(:daily_bento_a)
    price = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 600,
      effective_from: Time.current
    )

    assert_includes catalog.prices, price
  end

  test "pricing_rules との関連が正しく設定されている" do
    catalog = catalogs(:salad)
    rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: "bento",
      max_per_trigger: 1,
      valid_from: Date.current
    )

    assert_includes catalog.pricing_rules, rule
  end

  test "discontinuation との関連が正しく設定されている" do
    catalog = catalogs(:daily_bento_b)
    discontinuation = CatalogDiscontinuation.create!(
      catalog: catalog,
      discontinued_at: Time.current,
      reason: "テスト提供終了"
    )

    assert_equal discontinuation, catalog.discontinuation
  end

  # ===== ビジネスロジックメソッドテスト（Task 4.5 追加） =====

  test "current_price は現在有効な価格を取得" do
    catalog = Catalog.create!(name: "current_price テスト", category: :bento)

    # 過去の価格
    CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 400,
      effective_from: 2.days.ago,
      effective_until: 1.day.ago
    )

    # 現在有効な価格
    current = CatalogPrice.create!(
      catalog: catalog,
      kind: :regular,
      price: 500,
      effective_from: 1.day.ago,
      effective_until: nil
    )

    assert_equal current, catalog.current_price
  end

  test "current_price は有効な価格がない場合 nil を返す" do
    catalog = Catalog.create!(name: "価格なしテスト", category: :bento)
    assert_nil catalog.current_price
  end

  test "discontinued? は提供終了記録がある場合 true を返す" do
    catalog = catalogs(:salad)
    CatalogDiscontinuation.create!(
      catalog: catalog,
      discontinued_at: Time.current,
      reason: "テスト提供終了"
    )

    assert catalog.discontinued?
  end

  test "discontinued? は提供終了記録がない場合 false を返す" do
    catalog = catalogs(:daily_bento_a)
    assert_not catalog.discontinued?
  end
end
