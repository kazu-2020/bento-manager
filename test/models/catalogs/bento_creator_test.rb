# frozen_string_literal: true

require "test_helper"

class Catalogs::BentoCreatorTest < ActiveSupport::TestCase
  # ===== 弁当作成 =====

  test "弁当を作成できること" do
    creator = Catalogs::BentoCreator.new(
      name: "のり弁当",
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
    creator = Catalogs::BentoCreator.new(
      name: "のり弁当",
      regular_price: 450
    )

    assert_no_difference "CatalogPricingRule.count" do
      creator.create!
    end
  end

  test "description を設定できること" do
    creator = Catalogs::BentoCreator.new(
      name: "のり弁当",
      regular_price: 450,
      description: "海苔と鮭フレークをのせた弁当"
    )

    catalog = creator.create!
    assert_equal "海苔と鮭フレークをのせた弁当", catalog.description
  end

  test "description を省略した場合は空文字になること" do
    creator = Catalogs::BentoCreator.new(
      name: "のり弁当",
      regular_price: 450
    )

    catalog = creator.create!
    assert_equal "", catalog.description
  end

  # ===== valid? メソッド =====

  test "valid? は有効なデータで true を返すこと" do
    creator = Catalogs::BentoCreator.new(
      name: "テスト弁当",
      regular_price: 450
    )

    assert creator.valid?
    assert_empty creator.errors
  end

  test "valid? は name がない場合に false を返すこと" do
    creator = Catalogs::BentoCreator.new(
      name: "",
      regular_price: 450
    )

    assert_not creator.valid?
    assert_includes creator.errors[:name], "を入力してください"
  end

  test "valid? は regular_price が 0 以下の場合に false を返すこと" do
    creator = Catalogs::BentoCreator.new(
      name: "テスト弁当",
      regular_price: 0
    )

    assert_not creator.valid?
    assert_includes creator.errors[:regular_price], "は0より大きい値にしてください"
  end

  test "valid? は重複する name の場合に false を返すこと" do
    Catalog.create!(name: "既存弁当", category: :bento)

    creator = Catalogs::BentoCreator.new(
      name: "既存弁当",
      regular_price: 450
    )

    assert_not creator.valid?
    assert_includes creator.errors[:name], "はすでに存在します"
  end

  # ===== モデルバリデーション（委譲） =====

  test "name がない場合はモデルのバリデーションエラーになること" do
    creator = Catalogs::BentoCreator.new(
      name: "",
      regular_price: 450
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      creator.create!
    end
  end

  test "regular_price が0以下の場合はモデルのバリデーションエラーになること" do
    creator = Catalogs::BentoCreator.new(
      name: "テスト弁当",
      regular_price: 0
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      creator.create!
    end
  end

  # ===== トランザクション =====

  test "バリデーションエラー時は何も作成されないこと" do
    creator = Catalogs::BentoCreator.new(
      name: "",
      regular_price: 450
    )

    assert_no_difference [ "Catalog.count", "CatalogPrice.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        creator.create!
      end
    end
  end

  test "create メソッドはバリデーションエラー時に nil を返すこと" do
    creator = Catalogs::BentoCreator.new(
      name: "",
      regular_price: 450
    )

    result = creator.create
    assert_nil result
  end

  test "create メソッドは成功時にカタログを返すこと" do
    creator = Catalogs::BentoCreator.new(
      name: "テスト弁当",
      regular_price: 450
    )

    catalog = creator.create
    assert_kind_of Catalog, catalog
    assert_equal "テスト弁当", catalog.name
  end
end
