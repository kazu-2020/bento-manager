# frozen_string_literal: true

require "test_helper"

class Catalogs::CreatorTest < ActiveSupport::TestCase
  # ===== バリデーション =====

  test "name が必須であること" do
    creator = Catalogs::Creator.new(
      category: "bento",
      regular_price: 450
    )

    assert_not creator.valid?
    assert_includes creator.errors[:name], "を入力してください"
  end

  test "category が必須であること" do
    creator = Catalogs::Creator.new(
      name: "テスト弁当",
      regular_price: 450
    )

    assert_not creator.valid?
    assert_includes creator.errors[:category], "を入力してください"
  end

  test "category は bento または side_menu のみ許可されること" do
    creator = Catalogs::Creator.new(
      name: "テスト",
      category: "invalid_category",
      regular_price: 450
    )

    assert_not creator.valid?
    assert_includes creator.errors[:category], "は一覧にありません"
  end

  test "regular_price が必須であること" do
    creator = Catalogs::Creator.new(
      name: "テスト弁当",
      category: "bento"
    )

    assert_not creator.valid?
    assert_includes creator.errors[:regular_price], "を入力してください"
  end

  test "regular_price は0より大きい必要があること" do
    creator = Catalogs::Creator.new(
      name: "テスト弁当",
      category: "bento",
      regular_price: 0
    )

    assert_not creator.valid?
    assert_includes creator.errors[:regular_price], "は0より大きい値にしてください"
  end

  test "bundle_price は弁当には設定できないこと" do
    creator = Catalogs::Creator.new(
      name: "テスト弁当",
      category: "bento",
      regular_price: 450,
      bundle_price: 100
    )

    assert_not creator.valid?
    assert_includes creator.errors[:bundle_price], "はサイドメニューにのみ設定できます"
  end

  test "bundle_price は通常価格より低い必要があること" do
    creator = Catalogs::Creator.new(
      name: "テストサイドメニュー",
      category: "side_menu",
      regular_price: 100,
      bundle_price: 150
    )

    assert_not creator.valid?
    assert_includes creator.errors[:bundle_price], "は通常価格より低く設定してください"
  end

  # ===== 弁当作成 =====

  test "弁当を作成できること" do
    creator = Catalogs::Creator.new(
      name: "のり弁当",
      category: "bento",
      regular_price: 450
    )

    assert_difference [ "Catalog.count", "CatalogPrice.count" ], 1 do
      catalog = creator.create!
      assert_equal "のり弁当", catalog.name
      assert catalog.bento?
      assert_equal 1, catalog.prices.count
      assert_equal 450, catalog.prices.first.price
      assert catalog.prices.first.regular?
    end
  end

  test "弁当作成時に pricing_rule は作成されないこと" do
    creator = Catalogs::Creator.new(
      name: "のり弁当",
      category: "bento",
      regular_price: 450
    )

    assert_no_difference "CatalogPricingRule.count" do
      creator.create!
    end
  end

  # ===== サイドメニュー作成 =====

  test "サイドメニューを通常価格のみで作成できること" do
    creator = Catalogs::Creator.new(
      name: "唐揚げ",
      category: "side_menu",
      regular_price: 150
    )

    assert_difference [ "Catalog.count", "CatalogPrice.count" ], 1 do
      catalog = creator.create!
      assert_equal "唐揚げ", catalog.name
      assert catalog.side_menu?
      assert_equal 1, catalog.prices.count
      assert catalog.prices.first.regular?
    end
  end

  test "サイドメニューをセット価格付きで作成できること" do
    creator = Catalogs::Creator.new(
      name: "唐揚げ",
      category: "side_menu",
      regular_price: 150,
      bundle_price: 100
    )

    assert_difference "Catalog.count", 1 do
      assert_difference "CatalogPrice.count", 2 do
        assert_difference "CatalogPricingRule.count", 1 do
          catalog = creator.create!

          assert_equal "唐揚げ", catalog.name
          assert catalog.side_menu?

          regular_price = catalog.prices.find_by(kind: :regular)
          bundle_price = catalog.prices.find_by(kind: :bundle)

          assert_equal 150, regular_price.price
          assert_equal 100, bundle_price.price

          rule = CatalogPricingRule.find_by(target_catalog: catalog)
          assert rule.bundle?
          assert rule.triggered_by_bento?
          assert_equal 1, rule.max_per_trigger
        end
      end
    end
  end

  # ===== トランザクション =====

  test "バリデーションエラー時は何も作成されないこと" do
    creator = Catalogs::Creator.new(
      name: "",
      category: "bento",
      regular_price: 450
    )

    assert_no_difference [ "Catalog.count", "CatalogPrice.count", "CatalogPricingRule.count" ] do
      assert_raises(ActiveModel::ValidationError) do
        creator.create!
      end
    end
  end

  test "create メソッドはバリデーションエラー時に nil を返すこと" do
    creator = Catalogs::Creator.new(
      name: "",
      category: "bento",
      regular_price: 450
    )

    result = creator.create
    assert_nil result
  end

  test "create メソッドは成功時にカタログを返すこと" do
    creator = Catalogs::Creator.new(
      name: "テスト弁当",
      category: "bento",
      regular_price: 450
    )

    catalog = creator.create
    assert_kind_of Catalog, catalog
    assert_equal "テスト弁当", catalog.name
  end

  # ===== description =====

  test "description を設定できること" do
    creator = Catalogs::Creator.new(
      name: "のり弁当",
      category: "bento",
      regular_price: 450,
      description: "海苔と鮭フレークをのせた弁当"
    )

    catalog = creator.create!
    assert_equal "海苔と鮭フレークをのせた弁当", catalog.description
  end

  test "description を省略した場合は空文字になること" do
    creator = Catalogs::Creator.new(
      name: "のり弁当",
      category: "bento",
      regular_price: 450
    )

    catalog = creator.create!
    assert_equal "", catalog.description
  end
end
