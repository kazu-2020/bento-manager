# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class InventoryFormTest < ActiveSupport::TestCase
    fixtures :catalogs, :locations

    setup do
      @location = locations(:city_hall)
      @catalogs = Catalog.available.bento.order(:name)
      @bento_a = catalogs(:daily_bento_a)
      @bento_b = catalogs(:daily_bento_b)
    end

    test "initializes with all catalogs unselected" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      assert_equal @catalogs.count, form.items.count
      form.items.each do |item|
        assert_not item.selected?
        assert_equal 10, item.stock
      end
    end

    test "initializes with saved state" do
      state = {
        @bento_a.id.to_s => { selected: true, stock: 15 }
      }
      form = InventoryForm.new(location: @location, catalogs: @catalogs, state: state)

      item_a = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert item_a.selected?
      assert_equal 15, item_a.stock
    end

    test "toggle selects unselected item" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      form.toggle(@bento_a.id)

      item = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert item.selected?
    end

    test "toggle deselects selected item" do
      state = { @bento_a.id.to_s => { selected: true, stock: 10 } }
      form = InventoryForm.new(location: @location, catalogs: @catalogs, state: state)

      form.toggle(@bento_a.id)

      item = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert_not item.selected?
    end

    test "update_stock sets stock value" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      form.update_stock(@bento_a.id, 25)

      item = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert_equal 25, item.stock
    end

    test "update_stock clamps value between 1 and 999" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      form.update_stock(@bento_a.id, 0)
      item = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert_equal 1, item.stock

      form.update_stock(@bento_a.id, 1000)
      item = form.items.find { |i| i.catalog_id == @bento_a.id }
      assert_equal 999, item.stock
    end

    test "selected_items returns only selected items" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)
      form.toggle(@bento_a.id)

      assert_equal 1, form.selected_items.count
      assert_equal @bento_a.id, form.selected_items.first.catalog_id
    end

    test "selected_count returns number of selected items" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      assert_equal 0, form.selected_count

      form.toggle(@bento_a.id)
      assert_equal 1, form.selected_count

      form.toggle(@bento_b.id)
      assert_equal 2, form.selected_count
    end

    test "can_submit? returns false when nothing selected" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      assert_not form.can_submit?
    end

    test "can_submit? returns true when at least one item selected" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)
      form.toggle(@bento_a.id)

      assert form.can_submit?
    end

    test "to_state returns serializable hash" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)
      form.toggle(@bento_a.id)
      form.update_stock(@bento_a.id, 11)

      state = form.to_state

      assert_equal true, state[@bento_a.id.to_s][:selected]
      assert_equal 11, state[@bento_a.id.to_s][:stock]
    end

    test "to_inventory_params returns params for BulkCreator" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)
      form.toggle(@bento_a.id)
      form.toggle(@bento_b.id)
      form.update_stock(@bento_a.id, 15)
      form.update_stock(@bento_b.id, 20)

      params = form.to_inventory_params

      assert_equal 2, params[:inventories].count
      assert params[:inventories].any? { |i| i[:catalog_id] == @bento_a.id && i[:stock] == 15 }
      assert params[:inventories].any? { |i| i[:catalog_id] == @bento_b.id && i[:stock] == 20 }
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

  end
end
