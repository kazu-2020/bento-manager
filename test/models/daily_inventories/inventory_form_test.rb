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

    test "initializes with all catalogs unselected" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      assert_equal @catalogs.count, form.items.count
      form.items.each do |item|
        assert_not item.selected?
        assert_equal 10, item.stock
      end
    end

    test "initializes with submitted values" do
      submitted = {
        @bento_a.id.to_s => { selected: true, stock: 15 }
      }
      form = InventoryForm.new(location: @location, catalogs: @catalogs, submitted: submitted)

      item_a = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert item_a.selected?
      assert_equal 15, item_a.stock
    end

    test "selected_items returns only selected items" do
      submitted = { @bento_a.id.to_s => { selected: true } }
      form = InventoryForm.new(location: @location, catalogs: @catalogs, submitted: submitted)

      assert_equal 1, form.selected_items.count
      assert_equal @bento_a.id, form.selected_items.first.catalog_id
    end

    test "selected_count returns number of selected items" do
      submitted = {
        @bento_a.id.to_s => { selected: true },
        @bento_b.id.to_s => { selected: true }
      }
      form = InventoryForm.new(location: @location, catalogs: @catalogs, submitted: submitted)

      assert_equal 2, form.selected_count
    end

    test "valid? returns false when nothing selected" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      assert_not form.valid?
    end

    test "valid? returns true when at least one item selected" do
      submitted = { @bento_a.id.to_s => { selected: true } }
      form = InventoryForm.new(location: @location, catalogs: @catalogs, submitted: submitted)

      assert form.valid?
    end

    test "form_with_options returns url and method for daily inventories" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      expected = { url: "/pos/locations/#{@location.id}/daily_inventories", method: :post }
      assert_equal expected, form.form_with_options
    end

    test "form_state_options returns url and method for form state" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      expected = { url: "/pos/locations/#{@location.id}/daily_inventories/form_state", method: :post }
      assert_equal expected, form.form_state_options
    end

    # =====================================================================
    # カテゴリグルーピングテスト
    # =====================================================================

    test "items have category attribute from catalog" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      bento_item = form.items.find { |i| i.catalog_id == @bento_a.id }
      side_item = form.items.find { |i| i.catalog_id == @salad.id }

      assert_equal "bento", bento_item.category
      assert_equal "side_menu", side_item.category
    end

    test "bento_items returns only bento category items" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      form.bento_items.each do |item|
        assert_equal "bento", item.category
      end
      assert form.bento_items.any?
    end

    test "side_menu_items returns only side_menu category items" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      form.side_menu_items.each do |item|
        assert_equal "side_menu", item.category
      end
      assert form.side_menu_items.any?
    end

    # =====================================================================
    # save メソッドテスト
    # =====================================================================

    test "save は成功時 true を返し created_count を設定する" do
      location = Location.create!(name: "save テスト販売先", status: :active)
      submitted = {
        @bento_a.id.to_s => { selected: true, stock: 10 },
        @bento_b.id.to_s => { selected: true, stock: 5 }
      }
      form = InventoryForm.new(location: location, catalogs: @catalogs, submitted: submitted)

      assert_difference "DailyInventory.count", 2 do
        assert form.save
      end

      assert_equal 2, form.created_count
    end

    test "save はバリデーション失敗時 false を返す" do
      location = Location.create!(name: "バリデーションテスト販売先", status: :active)
      form = InventoryForm.new(location: location, catalogs: @catalogs)

      assert_no_difference "DailyInventory.count" do
        assert_not form.save
      end

      assert_equal 0, form.created_count
    end

    test "save は DB エラー時 false を返し errors にエラーを追加する" do
      location = Location.create!(name: "DB エラーテスト販売先", status: :active)
      DailyInventory.create!(
        location: location,
        catalog: @bento_a,
        inventory_date: Date.current,
        stock: 5,
        reserved_stock: 0
      )

      submitted = { @bento_a.id.to_s => { selected: true, stock: 15 } }
      form = InventoryForm.new(location: location, catalogs: @catalogs, submitted: submitted)

      assert_no_difference "DailyInventory.count" do
        assert_not form.save
      end

      assert_includes form.errors[:base], "保存に失敗しました。もう一度お試しください。"
    end
  end
end
