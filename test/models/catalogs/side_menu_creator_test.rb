# frozen_string_literal: true

require "test_helper"

class Catalogs::SideMenuCreatorTest < ActiveSupport::TestCase
  # ===== サイドメニュー作成（通常価格のみ） =====

  test "サイドメニューを通常価格のみで作成できること" do
    creator = Catalogs::SideMenuCreator.new(
      name: "唐揚げ",
      kana: "カラアゲ",
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

  test "通常価格のみの場合 pricing_rule は作成されないこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "唐揚げ",
      kana: "カラアゲ",
      regular_price: 150
    )

    assert_no_difference "CatalogPricingRule.count" do
      creator.create!
    end
  end

  # ===== サイドメニュー作成（セット価格あり） =====

  test "サイドメニューをセット価格付きで作成できること" do
    creator = Catalogs::SideMenuCreator.new(
      name: "唐揚げ",
      kana: "カラアゲ",
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

  # ===== description =====

  test "description を設定できること" do
    creator = Catalogs::SideMenuCreator.new(
      name: "唐揚げ",
      kana: "カラアゲ",
      regular_price: 150,
      description: "ジューシーな鶏の唐揚げ"
    )

    catalog = creator.create!
    assert_equal "ジューシーな鶏の唐揚げ", catalog.description
  end

  test "description を省略した場合は空文字になること" do
    creator = Catalogs::SideMenuCreator.new(
      name: "唐揚げ",
      kana: "カラアゲ",
      regular_price: 150
    )

    catalog = creator.create!
    assert_equal "", catalog.description
  end

  # ===== valid? メソッド =====

  test "valid? は有効なデータで true を返すこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "テストサイドメニュー",
      kana: "テストサイドメニュー",
      regular_price: 150
    )

    assert creator.valid?
    assert_empty creator.errors
  end

  test "valid? はセット価格付きで有効なデータでも true を返すこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "テストサイドメニュー",
      kana: "テストサイドメニュー",
      regular_price: 150,
      bundle_price: 100
    )

    assert creator.valid?
    assert_empty creator.errors
  end

  test "valid? は name がない場合に false を返すこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "",
      regular_price: 150
    )

    assert_not creator.valid?
    assert_includes creator.errors[:name], "を入力してください"
  end

  test "valid? は regular_price が 0 以下の場合に false を返すこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "テストサイドメニュー",
      kana: "テストサイドメニュー",
      regular_price: 0
    )

    assert_not creator.valid?
    assert_includes creator.errors[:regular_price], "は0より大きい値にしてください"
  end

  test "valid? は bundle_price が 0 以下の場合に false を返すこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "テストサイドメニュー",
      kana: "テストサイドメニュー",
      regular_price: 150,
      bundle_price: 0
    )

    assert_not creator.valid?
    assert_includes creator.errors[:bundle_price], "は0より大きい値にしてください"
  end

  test "valid? は重複する name の場合に false を返すこと" do
    Catalog.create!(name: "既存サイドメニュー", kana: "キゾンサイドメニュー", category: :side_menu)

    creator = Catalogs::SideMenuCreator.new(
      name: "既存サイドメニュー",
      kana: "キゾンサイドメニュー",
      regular_price: 150
    )

    assert_not creator.valid?
    assert_includes creator.errors[:name], "はすでに存在します"
  end

  # ===== モデルバリデーション（委譲） =====

  test "name がない場合はモデルのバリデーションエラーになること" do
    creator = Catalogs::SideMenuCreator.new(
      name: "",
      regular_price: 150
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      creator.create!
    end
  end

  test "regular_price が0以下の場合はモデルのバリデーションエラーになること" do
    creator = Catalogs::SideMenuCreator.new(
      name: "テストサイドメニュー",
      kana: "テストサイドメニュー",
      regular_price: 0
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      creator.create!
    end
  end

  test "bundle_price が0以下の場合はモデルのバリデーションエラーになること" do
    creator = Catalogs::SideMenuCreator.new(
      name: "テストサイドメニュー",
      kana: "テストサイドメニュー",
      regular_price: 150,
      bundle_price: 0
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      creator.create!
    end
  end

  # ===== トランザクション =====

  test "バリデーションエラー時は何も作成されないこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "",
      regular_price: 150
    )

    assert_no_difference [ "Catalog.count", "CatalogPrice.count", "CatalogPricingRule.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        creator.create!
      end
    end
  end

  test "create メソッドはバリデーションエラー時に nil を返すこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "",
      regular_price: 150
    )

    result = creator.create
    assert_nil result
  end

  test "create メソッドは成功時にカタログを返すこと" do
    creator = Catalogs::SideMenuCreator.new(
      name: "テストサイドメニュー",
      kana: "テストサイドメニュー",
      regular_price: 150
    )

    catalog = creator.create
    assert_kind_of Catalog, catalog
    assert_equal "テストサイドメニュー", catalog.name
  end
end
