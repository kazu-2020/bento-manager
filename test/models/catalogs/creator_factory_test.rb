# frozen_string_literal: true

require "test_helper"

class Catalogs::CreatorFactoryTest < ActiveSupport::TestCase
  # ===== build =====

  test "bento カテゴリで BentoCreator を生成できること" do
    creator = Catalogs::CreatorFactory.build("bento", name: "のり弁当", regular_price: 450)

    assert_kind_of Catalogs::BentoCreator, creator
    assert_equal "のり弁当", creator.name
    assert_equal 450, creator.regular_price
  end

  test "side_menu カテゴリで SideMenuCreator を生成できること" do
    creator = Catalogs::CreatorFactory.build("side_menu", name: "唐揚げ", regular_price: 150, bundle_price: 100)

    assert_kind_of Catalogs::SideMenuCreator, creator
    assert_equal "唐揚げ", creator.name
    assert_equal 150, creator.regular_price
    assert_equal 100, creator.bundle_price
  end

  test "不明なカテゴリの場合 InvalidCategoryError を発生させること" do
    assert_raises(Catalogs::CreatorFactory::InvalidCategoryError) do
      Catalogs::CreatorFactory.build("unknown")
    end
  end

  test "属性なしで生成できること" do
    creator = Catalogs::CreatorFactory.build("bento")

    assert_kind_of Catalogs::BentoCreator, creator
    assert_nil creator.name
  end

  # ===== creator_class_for =====

  test "bento カテゴリで BentoCreator クラスを返すこと" do
    klass = Catalogs::CreatorFactory.creator_class_for("bento")

    assert_equal Catalogs::BentoCreator, klass
  end

  test "side_menu カテゴリで SideMenuCreator クラスを返すこと" do
    klass = Catalogs::CreatorFactory.creator_class_for("side_menu")

    assert_equal Catalogs::SideMenuCreator, klass
  end

  test "creator_class_for で不明なカテゴリの場合 InvalidCategoryError を発生させること" do
    assert_raises(Catalogs::CreatorFactory::InvalidCategoryError) do
      Catalogs::CreatorFactory.creator_class_for("invalid")
    end
  end
end
