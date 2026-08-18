# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class InventoryFormTest < ActiveSupport::TestCase
    include GhostFormSubmissionHelper

    fixtures :catalogs, :locations

    setup do
      @location = locations(:city_hall)
      @catalogs = Catalog.available.category_order
      @bento_a = catalogs(:daily_bento_a)
      @bento_b = catalogs(:daily_bento_b)
      @salad = catalogs(:salad)
    end

    def submission_form
      InventoryForm
    end

    def build(location: @location, search_query: nil, submitted: ::GhostForms::Submission.absent)
      InventoryForm.new(
        location: location, catalogs: @catalogs,
        search_query: search_query, submitted: submitted
      )
    end

    test "商品一覧から在庫フォームを構築し選択した商品で絞り込める" do
      form = build

      assert_equal @catalogs.count, form.items.count
      form.items.each do |item|
        assert_not item.selected?
        assert_equal InventoryItem::DEFAULT_STOCK, item.stock
      end
      assert_not form.valid?

      form_with_input = build(submitted: submission({
        @bento_a.id.to_s => { "selected" => "1", "stock" => "15" },
        @bento_b.id.to_s => { "selected" => "1", "stock" => "5" }
      }))

      assert_predicate form_with_input, :valid?
      assert_equal 2, form_with_input.selected_count
      assert_equal 15, form_with_input.selected_items.find { |i| i.catalog_id == @bento_a.id }.stock
    end

    test "商品をカテゴリごとに分類できる" do
      form = build

      assert_predicate form.bento_items, :any?
      form.bento_items.each { |item| assert_equal "bento", item.category }

      assert_predicate form.side_menu_items, :any?
      form.side_menu_items.each { |item| assert_equal "side_menu", item.category }
    end

    test "商品名で検索して表示を絞り込める" do
      form = build(search_query: @bento_a.name[0..2])
      matching_item = form.items.find { |i| i.catalog_id == @bento_a.id }

      assert form.visible?(matching_item)

      form_no_match = build(search_query: "存在しない商品名")

      assert_not form_no_match.visible?(form_no_match.items.first)

      form_blank = build(search_query: "  弁当  ")

      assert_equal "弁当", form_blank.search_query

      form_empty = build(search_query: "   ")

      assert_nil form_empty.search_query
    end

    test "在庫を保存でき失敗時はエラーを返す" do
      location = Location.create!(name: "save テスト販売先", status: :active)
      form = build(location: location, submitted: submission({
        @bento_a.id.to_s => { "selected" => "1", "stock" => "10" },
        @bento_b.id.to_s => { "selected" => "1", "stock" => "5" }
      }))

      assert_difference "DailyInventory.count", 2 do
        assert form.save
      end
      assert_equal 2, form.created_count

      empty_form = build(location: location)

      assert_not empty_form.save
      assert_equal 0, empty_form.created_count

      dup_location = Location.create!(name: "重複テスト販売先", status: :active)
      DailyInventory.create!(location: dup_location, catalog: @bento_a, inventory_date: Date.current, stock: 5, reserved_stock: 0)
      dup_form = build(location: dup_location, submitted: submission({
        @bento_a.id.to_s => { "selected" => "1", "stock" => "15" }
      }))

      assert_not dup_form.save
      assert_includes dup_form.errors[:base], "保存に失敗しました。もう一度お試しください。"
    end
  end
end
