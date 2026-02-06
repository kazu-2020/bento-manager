# frozen_string_literal: true

require "test_helper"

class Catalogs::SideMenuCreatorTest < ActiveSupport::TestCase
  test "サイドメニューを通常価格のみで作成できる" do
    creator = Catalogs::SideMenuCreator.new(
      name: "唐揚げ",
      kana: "カラアゲ",
      regular_price: 150,
      description: "ジューシーな鶏の唐揚げ"
    )

    assert creator.valid?

    assert_difference [ "Catalog.count", "CatalogPrice.count" ], 1 do
      assert_no_difference "CatalogPricingRule.count" do
        catalog = creator.create!

        assert_equal "唐揚げ", catalog.name
        assert catalog.side_menu?
        assert catalog.prices.first.regular?
        assert_equal "ジューシーな鶏の唐揚げ", catalog.description
      end
    end
  end

  test "セット価格付きで作成すると価格ルールも一緒に作成される" do
    creator = Catalogs::SideMenuCreator.new(
      name: "唐揚げ",
      kana: "カラアゲ",
      regular_price: 150,
      bundle_price: 100
    )

    assert creator.valid?

    assert_difference "Catalog.count", 1 do
      assert_difference "CatalogPrice.count", 2 do
        assert_difference "CatalogPricingRule.count", 1 do
          catalog = creator.create!

          assert_equal 150, catalog.prices.find_by(kind: :regular).price
          assert_equal 100, catalog.prices.find_by(kind: :bundle).price

          rule = CatalogPricingRule.find_by(target_catalog: catalog)
          assert rule.bundle?
          assert rule.triggered_by_bento?
          assert_equal 1, rule.max_per_trigger
        end
      end
    end
  end

  test "不正なデータでは作成されず事前検証もできる" do
    creator = Catalogs::SideMenuCreator.new(name: "", regular_price: 0)

    assert_not creator.valid?
    assert creator.errors[:name].any?
    assert creator.errors[:regular_price].any?

    assert_no_difference [ "Catalog.count", "CatalogPrice.count", "CatalogPricingRule.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { creator.create! }
    end

    assert_nil creator.create

    creator_with_bad_bundle = Catalogs::SideMenuCreator.new(
      name: "テスト", kana: "テスト", regular_price: 150, bundle_price: 0
    )
    assert_not creator_with_bad_bundle.valid?
    assert creator_with_bad_bundle.errors[:bundle_price].any?
  end

  test "商品名が重複している場合は作成できない" do
    Catalog.create!(name: "既存サイドメニュー", kana: "キゾンサイドメニュー", category: :side_menu)

    creator = Catalogs::SideMenuCreator.new(name: "既存サイドメニュー", kana: "キゾンサイドメニュー", regular_price: 150)

    assert_not creator.valid?
    assert_includes creator.errors[:name], "はすでに存在します"
  end
end
