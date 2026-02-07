# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class InventoryFormTest < ActiveSupport::TestCase
    fixtures :catalogs, :locations

    setup do
      @location = locations(:city_hall)
      @catalogs = Catalog.available.category_order
      @bento_a = catalogs(:daily_bento_a)
      @bento_b = catalogs(:daily_bento_b)
      @salad = catalogs(:salad)
    end

    test "商品一覧から在庫フォームを構築し選択した商品で絞り込める" do
      items = ItemBuilder.from_params(@catalogs, {})
      form = InventoryForm.new(location: @location, items: items)

      assert_equal @catalogs.count, form.items.count
      form.items.each do |item|
        assert_not item.selected?
        assert_equal 10, item.stock
      end
      assert_not form.valid?

      submitted = {
        @bento_a.id.to_s => { selected: true, stock: 15 },
        @bento_b.id.to_s => { selected: true, stock: 5 }
      }
      items_with_input = ItemBuilder.from_params(@catalogs, submitted)
      form_with_input = InventoryForm.new(location: @location, items: items_with_input)

      assert form_with_input.valid?
      assert_equal 2, form_with_input.selected_count
      assert_equal 15, form_with_input.selected_items.find { |i| i.catalog_id == @bento_a.id }.stock
    end

    test "商品をカテゴリごとに分類できる" do
      items = ItemBuilder.from_params(@catalogs, {})
      form = InventoryForm.new(location: @location, items: items)

      assert form.bento_items.any?
      form.bento_items.each { |item| assert_equal "bento", item.category }

      assert form.side_menu_items.any?
      form.side_menu_items.each { |item| assert_equal "side_menu", item.category }
    end

    test "商品名で検索して表示を絞り込める" do
      items = ItemBuilder.from_params(@catalogs, {})

      form = InventoryForm.new(location: @location, items: items, search_query: @bento_a.name[0..2])
      matching_item = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert form.visible?(matching_item)

      form_no_match = InventoryForm.new(location: @location, items: items, search_query: "存在しない商品名")
      assert_not form_no_match.visible?(form_no_match.items.first)

      form_blank = InventoryForm.new(location: @location, items: items, search_query: "  弁当  ")
      assert_equal "弁当", form_blank.search_query

      form_empty = InventoryForm.new(location: @location, items: items, search_query: "   ")
      assert_nil form_empty.search_query
    end

    test "在庫を保存でき失敗時はエラーを返す" do
      location = Location.create!(name: "save テスト販売先", status: :active)
      submitted = {
        @bento_a.id.to_s => { selected: true, stock: 10 },
        @bento_b.id.to_s => { selected: true, stock: 5 }
      }
      items = ItemBuilder.from_params(@catalogs, submitted)
      form = InventoryForm.new(location: location, items: items)

      assert_difference "DailyInventory.count", 2 do
        assert form.save
      end
      assert_equal 2, form.created_count

      empty_items = ItemBuilder.from_params(@catalogs, {})
      empty_form = InventoryForm.new(location: location, items: empty_items)
      assert_not empty_form.save
      assert_equal 0, empty_form.created_count

      dup_location = Location.create!(name: "重複テスト販売先", status: :active)
      DailyInventory.create!(location: dup_location, catalog: @bento_a, inventory_date: Date.current, stock: 5, reserved_stock: 0)
      dup_items = ItemBuilder.from_params(@catalogs, { @bento_a.id.to_s => { selected: true, stock: 15 } })
      dup_form = InventoryForm.new(location: dup_location, items: dup_items)

      assert_not dup_form.save
      assert_includes dup_form.errors[:base], "保存に失敗しました。もう一度お試しください。"
    end
  end
end
