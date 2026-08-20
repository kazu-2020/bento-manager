require "test_helper"

class CatalogTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_prices

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

  test "商品カタログの提供状態は提供終了記録の有無で決まる" do
    available = Catalog.create!(name: "提供中弁当", kana: "テイキョウチュウベントウ", category: :bento)
    discontinued = Catalog.create!(name: "提供終了弁当", kana: "テイキョウシュウリョウベントウ", category: :bento)
    discontinued.create_discontinuation!(discontinued_at: Time.current, reason: "終了")

    assert_equal :available, available.status
    assert_equal :discontinued, discontinued.status
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

  test "価格ルールを読み込み済みの商品は、追加の問い合わせなしで指定日に有効なルールを引ける" do
    catalog = Catalog.create!(name: "読み込み済みルールテスト", kana: "ヨミコミズミルールテスト", category: :side_menu)
    past_rule = CatalogPricingRule.create!(
      target_catalog: catalog, price_kind: :bundle, trigger_category: :bento,
      max_per_trigger: 1, valid_from: 2.months.ago.to_date, valid_until: 1.month.ago.to_date
    )
    current_rule = CatalogPricingRule.create!(
      target_catalog: catalog, price_kind: :bundle, trigger_category: :bento,
      max_per_trigger: 1, valid_from: 1.week.ago.to_date, valid_until: nil
    )
    loaded = Catalog.preload(:pricing_rules).find(catalog.id)

    assert_no_queries do
      assert_equal [ current_rule ], loaded.active_pricing_rules_at(Date.current)
      assert_equal [ past_rule ], loaded.active_pricing_rules_at(1.month.ago.to_date), "基準日を変えても選び直せる"
      assert_empty loaded.active_pricing_rules_at(1.year.ago.to_date), "どのルールも有効でない日では空になる"
    end
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

  test "価格を読み込み済みの商品は、追加の問い合わせなしで種別ごとの有効な価格を引ける" do
    catalog = catalogs(:salad)
    past_price = CatalogPrice.create!(
      catalog: catalog, kind: :regular, price: 200,
      effective_from: 3.days.ago, effective_until: 2.days.ago
    )
    catalog.prices.reload

    assert_no_queries do
      assert_equal 250, catalog.price_by_kind(:regular).price
      assert_equal 150, catalog.price_by_kind(:bundle).price
      assert_equal past_price, catalog.price_by_kind(:regular, at: 2.days.ago - 1.hour), "有効期間で切り替わる"
      assert_nil catalog.price_by_kind(:regular, at: 1.year.ago), "どの価格も有効でない時点では nil"
      assert_not catalog.price_exists?(:regular, at: 1.year.ago)
    end
  end

  test "保存前の価格は、読み込み済みの一覧に並んでいても選ばれない" do
    catalog = Catalog.preload(:prices).find(catalogs(:daily_bento_a).id)

    # 価格編集の入口が空のレコードを組み立てると、読み込み済みの一覧に紛れ込む
    # （CatalogPricesController#edit の `price_by_kind || prices.build` がこの形）
    catalog.prices.build(kind: :bundle)
    catalog.prices.build(kind: :regular, price: 9999, effective_from: Time.current)

    assert_nil catalog.price_by_kind(:bundle), "保存前のレコードを掴んではいけない"
    assert_not catalog.price_exists?(:bundle)
    assert_equal 550, catalog.price_by_kind(:regular).price, "保存済みの価格が保存前に負けてはいけない"
  end

  # 2 経路が一致することだけを見ても、どちらも id 昇順で拾っている状態を通してしまう
  # （SQLite はこの規模なら索引を使わず rowid 順に返し、max_by も最初の最大値を返す）。
  # 「後から作った価格が勝つ」という決め方そのものを両経路に対して押さえる
  test "適用開始日時が同じ価格が並んだら、後から作ったほうが勝つ" do
    catalog = Catalog.create!(name: "同時刻価格テスト", kana: "ドウジコクカカクテスト", category: :bento)
    started_at = 1.day.ago
    # 終了していない価格は商品・種別ごとに 1 件しか置けないので、同着を作るには
    # 両方に終了時刻を入れる。終了が未来にある間は現時点でどちらも有効なまま
    prices = 2.times.map do |i|
      CatalogPrice.create!(
        catalog: catalog, kind: :regular, price: 100 * (i + 1),
        effective_from: started_at, effective_until: 1.day.from_now
      )
    end
    latest = prices.max_by(&:id)

    assert_equal latest.id, Catalog.find(catalog.id).price_by_kind(:regular).id
    assert_equal latest.id, Catalog.preload(:prices).find(catalog.id).price_by_kind(:regular).id
  end

  test "価格の読み込み済みかどうかで、取得できる価格は変わらない" do
    catalog = catalogs(:salad)
    ended = CatalogPrice.create!(
      catalog: catalog, kind: :regular, price: 200,
      effective_from: 1.year.ago, effective_until: 7.months.ago
    )
    # 保存で丸められた後の値を使う。Ruby 側の精度のままだと境界ちょうどにならない
    ended_at = ended.reload.effective_until

    # 日付ちょうどの境界は SQL 側が文字列比較になり、Ruby 側と食い違いやすい
    boundary = Date.new(2026, 3, 10)
    # 終了時刻は fixture の salad_bundle と終了していない価格が並ばないために置く。
    # 未来に取ってあるので、以下のどの基準時刻から見ても有効なままである
    CatalogPrice.create!(
      catalog: catalog, kind: :bundle, price: 120,
      effective_from: boundary.to_time(:utc), effective_until: 1.year.from_now
    )

    # 有効期間の両端そのもの（ended_at / boundary）を含める。両端 inclusive かどうかは
    # 2 経路で食い違いやすく、境界ちょうどのデータが無いと素通りする
    base_times = [
      Time.current, 2.weeks.ago, 6.months.ago, 2.years.ago,
      Date.current, 6.months.ago.to_date, 2.weeks.ago.to_datetime,
      boundary, boundary - 1, boundary + 1,
      ended_at, ended_at - 1.second, ended_at + 1.second
    ]
    preloaded = Catalog.preload(:prices).find(catalog.id)

    # kind は呼び出し元によってシンボル・文字列・enum の整数のいずれも渡りうる
    [ :regular, "regular", :bundle, CatalogPrice.kinds[:bundle] ].each do |kind|
      unloaded = base_times.index_with { |at| Catalog.find(catalog.id).price_by_kind(kind, at: at)&.id }
      loaded   = base_times.index_with { |at| preloaded.price_by_kind(kind, at: at)&.id }

      assert_equal unloaded, loaded, "kind: #{kind.inspect} で preload の有無により結果が変わった"
    end
  end

  test "提供終了した商品は販売可能な一覧から除外される" do
    available_catalog = Catalog.create!(name: "販売中弁当", kana: "ハンバイチュウベントウ", category: :bento)
    discontinued_catalog = Catalog.create!(name: "終了弁当", kana: "シュウリョウベントウ", category: :bento)

    CatalogDiscontinuation.create!(
      catalog: discontinued_catalog,
      discontinued_at: Time.current,
      reason: "提供終了"
    )

    assert_predicate discontinued_catalog, :discontinued?
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
    assert_predicate catalog, :persisted?, "レコードは削除されていないべき"
  end
  test "提供終了した商品でも当日在庫があれば在庫訂正の対象に含まれる" do
    location = Location.create!(name: "母集合テスト販売先", status: :active)
    stocked = Catalog.create!(name: "積載済み終了弁当", kana: "セキサイズミシュウリョウベントウ", category: :bento)
    unstocked = Catalog.create!(name: "未積載終了弁当", kana: "ミセキサイシュウリョウベントウ", category: :bento)
    DailyInventory.create!(
      location: location, catalog: stocked,
      inventory_date: Date.current, stock: 3, reserved_stock: 0
    )
    [ stocked, unstocked ].each do |catalog|
      CatalogDiscontinuation.create!(catalog: catalog, discontinued_at: Time.current, reason: "提供終了")
    end

    catalogs = Catalog.available_or_stocked_at(location)

    assert_includes catalogs, stocked
    assert_not_includes catalogs, unstocked
  end
end
