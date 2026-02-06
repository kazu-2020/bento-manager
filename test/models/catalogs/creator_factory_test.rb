# frozen_string_literal: true

require "test_helper"

class Catalogs::CreatorFactoryTest < ActiveSupport::TestCase
  test "カテゴリに応じた作成クラスを生成し不明なカテゴリではエラーになる" do
    bento_creator = Catalogs::CreatorFactory.build("bento", name: "のり弁当", regular_price: 450)
    assert_kind_of Catalogs::BentoCreator, bento_creator
    assert_equal "のり弁当", bento_creator.name

    side_menu_creator = Catalogs::CreatorFactory.build("side_menu", name: "唐揚げ", regular_price: 150, bundle_price: 100)
    assert_kind_of Catalogs::SideMenuCreator, side_menu_creator
    assert_equal "唐揚げ", side_menu_creator.name

    assert_equal Catalogs::BentoCreator, Catalogs::CreatorFactory.creator_class_for("bento")
    assert_equal Catalogs::SideMenuCreator, Catalogs::CreatorFactory.creator_class_for("side_menu")

    assert_raises(Catalogs::CreatorFactory::InvalidCategoryError) do
      Catalogs::CreatorFactory.build("unknown")
    end
  end
end
