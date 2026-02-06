# frozen_string_literal: true

require "test_helper"

class Catalogs::BentoCreatorTest < ActiveSupport::TestCase
  test "弁当を商品と通常価格付きで作成できる" do
    creator = Catalogs::BentoCreator.new(
      name: "のり弁当",
      kana: "ノリベントウ",
      regular_price: 450,
      description: "海苔と鮭フレークをのせた弁当"
    )

    assert creator.valid?

    assert_difference [ "Catalog.count", "CatalogPrice.count" ], 1 do
      assert_no_difference "CatalogPricingRule.count" do
        catalog = creator.create!

        assert_equal "のり弁当", catalog.name
        assert catalog.bento?
        assert_equal 450, catalog.prices.first.price
        assert catalog.prices.first.regular?
        assert_equal "海苔と鮭フレークをのせた弁当", catalog.description
      end
    end
  end

  test "説明なしの場合は空文字で作成される" do
    creator = Catalogs::BentoCreator.new(
      name: "のり弁当",
      kana: "ノリベントウ",
      regular_price: 450
    )

    catalog = creator.create!
    assert_equal "", catalog.description
  end

  test "不正なデータでは作成されず事前検証もできる" do
    creator = Catalogs::BentoCreator.new(name: "", regular_price: 0)

    assert_not creator.valid?
    assert creator.errors[:name].any?
    assert creator.errors[:regular_price].any?

    assert_no_difference [ "Catalog.count", "CatalogPrice.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { creator.create! }
    end

    assert_nil creator.create
  end

  test "商品名が重複している場合は作成できない" do
    Catalog.create!(name: "既存弁当", kana: "キゾンベントウ", category: :bento)

    creator = Catalogs::BentoCreator.new(name: "既存弁当", kana: "キゾンベントウ", regular_price: 450)

    assert_not creator.valid?
    assert_includes creator.errors[:name], "はすでに存在します"
  end
end
