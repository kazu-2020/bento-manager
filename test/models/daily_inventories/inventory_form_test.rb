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

    test "can_submit? returns false when nothing selected" do
      form = InventoryForm.new(location: @location, catalogs: @catalogs)

      assert_not form.can_submit?
    end

    test "can_submit? returns true when at least one item selected" do
      submitted = { @bento_a.id.to_s => { selected: true } }
      form = InventoryForm.new(location: @location, catalogs: @catalogs, submitted: submitted)

      assert form.can_submit?
    end

    test "to_inventory_params returns params for BulkCreator" do
      submitted = {
        @bento_a.id.to_s => { selected: true, stock: 15 },
        @bento_b.id.to_s => { selected: true, stock: 20 }
      }
      form = InventoryForm.new(location: @location, catalogs: @catalogs, submitted: submitted)

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
