require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  fixtures :catalogs

  # ===== バリデーションテスト =====

  test "name は必須" do
    catalog = Catalog.new(name: nil, kana: "テストベントウ", category: :bento)
    assert_not catalog.valid?
    assert_includes catalog.errors[:name], "を入力してください"
  end

  test "category は必須" do
    catalog = Catalog.new(name: "テスト弁当", kana: "テストベントウ", category: nil)
    assert_not catalog.valid?
    assert_includes catalog.errors[:category], "を入力してください"
  end

  test "kana は必須" do
    catalog = Catalog.new(name: "テスト弁当", kana: nil, category: :bento)
    assert_not catalog.valid?
    assert_includes catalog.errors[:kana], "を入力してください"
  end

  test "kana はカタカナのみ許可" do
    catalog = Catalog.new(name: "テスト弁当", kana: "てすとべんとう", category: :bento)
    assert_not catalog.valid?
    assert_includes catalog.errors[:kana], "はカタカナで入力してください"
  end

  test "kana に漢字を含むとバリデーションエラー" do
    catalog = Catalog.new(name: "テスト弁当", kana: "テスト弁当", category: :bento)
    assert_not catalog.valid?
    assert_includes catalog.errors[:kana], "はカタカナで入力してください"
  end

  test "kana に長音符（ー）を含んでも有効" do
    catalog = Catalog.new(name: "カレー", kana: "カレー", category: :bento)
    assert catalog.valid?, "長音符を含む kana は有効であるべき: #{catalog.errors.full_messages.join(', ')}"
  end

  test "有効な属性で作成できる" do
    catalog = Catalog.new(name: "新規テスト弁当", kana: "シンキテストベントウ", category: :bento, description: "本日のおすすめ弁当")
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
    bento = Catalog.create!(name: "テスト弁当", kana: "テストベントウ", category: :bento)
    side_menu = Catalog.create!(name: "テストサラダ", kana: "テストサラダ", category: :side_menu)

    assert_includes Catalog.bento, bento
    assert_not_includes Catalog.bento, side_menu
  end

  test "side_menu スコープは side_menu カテゴリのみ取得" do
    bento = Catalog.create!(name: "テスト弁当B", kana: "テストベントウビー", category: :bento)
    side_menu = Catalog.create!(name: "テストサラダB", kana: "テストサラダビー", category: :side_menu)

    assert_includes Catalog.side_menu, side_menu
    assert_not_includes Catalog.side_menu, bento
  end

  # ===== Enum 更新メソッドテスト =====

  test "bento! で category を bento に変更" do
    catalog = Catalog.create!(name: "変更テスト商品", kana: "ヘンコウテストショウヒン", category: :side_menu)
    catalog.bento!
    assert catalog.bento?
  end

  test "side_menu! で category を side_menu に変更" do
    catalog = Catalog.create!(name: "変更テスト商品2", kana: "ヘンコウテストショウヒンニ", category: :bento)
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
    Catalog.create!(name: "テスト弁当X", kana: "テストベントウエックス", category: :bento)

    duplicate = Catalog.new(name: "テスト弁当X", kana: "テストベントウエックス", category: :bento)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "はすでに存在します"
  end

  test "name のユニーク制約は大文字小文字を区別しない" do
    Catalog.create!(name: "Test Bento", kana: "テストベントウ", category: :bento)

    duplicate = Catalog.new(name: "test bento", kana: "テストベントウ", category: :bento)
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

  test "active_pricing_rules は現在有効なルールのみ取得" do
    catalog = Catalog.create!(name: "active_pricing_rules テスト", kana: "アクティブプライシングルールステスト", category: :side_menu)

    # 過去のルール（有効期限切れ）
    past_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 2.months.ago,
      valid_until: 1.month.ago
    )

    # 現在有効なルール
    current_rule = CatalogPricingRule.create!(
      target_catalog: catalog,
      price_kind: :bundle,
      trigger_category: :bento,
      max_per_trigger: 1,
      valid_from: 1.week.ago,
      valid_until: nil
    )

    # 未来のルール（まだ有効でない）
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

  test "price_by_kind は指定した kind の現在有効な価格を取得" do
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
  end

  test "price_by_kind は有効な価格がない場合 nil を返す" do
    catalog = Catalog.create!(name: "価格なしテスト2", kana: "カカクナシテストニ", category: :bento)
    assert_nil catalog.price_by_kind(:regular)
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

  # ===== available スコープテスト =====

  test "available スコープは提供終了していない商品のみ取得" do
    available_catalog = Catalog.create!(name: "販売中弁当", kana: "ハンバイチュウベントウ", category: :bento)
    discontinued_catalog = Catalog.create!(name: "終了弁当", kana: "シュウリョウベントウ", category: :bento)

    CatalogDiscontinuation.create!(
      catalog: discontinued_catalog,
      discontinued_at: Time.current,
      reason: "販売終了"
    )

    assert_includes Catalog.available, available_catalog
    assert_not_includes Catalog.available, discontinued_catalog
  end

  test "available スコープは他のスコープとチェーン可能" do
    available_bento = Catalog.create!(name: "販売中弁当C", kana: "ハンバイチュウベントウシー", category: :bento)
    available_side = Catalog.create!(name: "販売中サイド", kana: "ハンバイチュウサイド", category: :side_menu)
    discontinued_bento = Catalog.create!(name: "終了弁当C", kana: "シュウリョウベントウシー", category: :bento)

    CatalogDiscontinuation.create!(
      catalog: discontinued_bento,
      discontinued_at: Time.current,
      reason: "販売終了"
    )

    result = Catalog.available.bento
    assert_includes result, available_bento
    assert_not_includes result, available_side
    assert_not_includes result, discontinued_bento
  end

  # ===== display_order スコープテスト =====

  test "display_order は販売中を先に、同じ状態内では kana 昇順" do
    available_b = Catalog.create!(name: "B弁当販売中", kana: "ビーベントウハンバイチュウ", category: :bento)
    available_a = Catalog.create!(name: "A弁当販売中", kana: "エーベントウハンバイチュウ", category: :bento)
    discontinued_b = Catalog.create!(name: "B弁当終了", kana: "ビーベントウシュウリョウ", category: :bento)
    discontinued_a = Catalog.create!(name: "A弁当終了", kana: "エーベントウシュウリョウ", category: :bento)

    CatalogDiscontinuation.create!(catalog: discontinued_b, discontinued_at: Time.current, reason: "終了")
    CatalogDiscontinuation.create!(catalog: discontinued_a, discontinued_at: Time.current, reason: "終了")

    result = Catalog.where(id: [ available_a, available_b, discontinued_a, discontinued_b ]).display_order.to_a

    # 販売中が先（エー, ビー）、販売停止が後（エー, ビー）の kana 順
    assert_equal [ available_a, available_b, discontinued_a, discontinued_b ], result
  end

  # ===== category_order スコープテスト =====

  test "category_order は弁当を先、サイドメニューを後に kana 順で返す" do
    bento_b = Catalog.create!(name: "B弁当", kana: "ビーベントウ", category: :bento)
    bento_a = Catalog.create!(name: "A弁当", kana: "エーベントウ", category: :bento)
    side_b = Catalog.create!(name: "Bサイド", kana: "ビーサイド", category: :side_menu)
    side_a = Catalog.create!(name: "Aサイド", kana: "エーサイド", category: :side_menu)

    result = Catalog.where(id: [ bento_a, bento_b, side_a, side_b ]).category_order.to_a

    # 弁当（エー, ビー）、サイドメニュー（エー, ビー）の kana 順
    assert_equal [ bento_a, bento_b, side_a, side_b ], result
  end

  # ===== 削除禁止テスト =====

  test "物理削除は禁止されている" do
    catalog = catalogs(:daily_bento_a)
    initial_count = Catalog.count

    result = catalog.destroy

    assert_not result, "destroy は false を返すべき"
    assert_equal initial_count, Catalog.count, "レコード数は変わらないべき"
    assert catalog.persisted?, "レコードは削除されていないべき"
  end

  test "destroy! は例外を発生させない（abort で中断）" do
    catalog = catalogs(:daily_bento_a)

    # before_destroy で throw :abort するため、destroy! は false を返す
    # （RecordNotDestroyed 例外は発生しない）
    result = catalog.destroy

    assert_not result
    assert catalog.persisted?
  end
end
