# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module AdditionalOrders
  class OrderFormTest < ActiveSupport::TestCase
    fixtures :locations, :catalogs, :daily_inventories, :employees

    setup do
      @location = locations(:city_hall)
      @employee = employees(:verified_employee)
      @inventories = @location.today_inventories
                              .eager_load(:catalog)
                              .merge(Catalog.where(category: :bento))
                              .order("catalogs.name")
    end

    test "builds items from inventories" do
      form = OrderForm.new(location: @location, inventories: @inventories)

      assert form.items.any?
      form.items.each do |item|
        assert_kind_of AdditionalOrders::OrderItem, item
        assert item.catalog_name.present?
        assert_equal 0, item.quantity
      end
    end

    test "builds items with submitted quantities" do
      bento_a = catalogs(:daily_bento_a)
      submitted = { bento_a.id.to_s => { quantity: "5" } }

      form = OrderForm.new(location: @location, inventories: @inventories, submitted: submitted)

      item = form.items.find { |i| i.catalog_id == bento_a.id }
      assert_equal 5, item.quantity
    end

    test "items_with_quantity filters items with positive quantity" do
      bento_a = catalogs(:daily_bento_a)
      submitted = {
        bento_a.id.to_s => { quantity: "3" }
      }

      form = OrderForm.new(location: @location, inventories: @inventories, submitted: submitted)

      assert_equal 1, form.items_with_quantity.count
      assert_equal bento_a.id, form.items_with_quantity.first.catalog_id
    end

    test "total_available_stock sums all item available_stock" do
      form = OrderForm.new(location: @location, inventories: @inventories)

      expected_total = @inventories.sum(&:available_stock)
      assert_equal expected_total, form.total_available_stock
    end

    test "save creates additional orders for items with quantity" do
      bento_a = catalogs(:daily_bento_a)
      bento_b = catalogs(:daily_bento_b)
      submitted = {
        bento_a.id.to_s => { quantity: "3" },
        bento_b.id.to_s => { quantity: "2" }
      }

      form = OrderForm.new(location: @location, inventories: @inventories, submitted: submitted)

      assert_difference "AdditionalOrder.count", 2 do
        assert form.save(employee: @employee)
      end

      assert_equal 2, form.created_count
    end

    test "save increments inventory stock" do
      bento_a = catalogs(:daily_bento_a)
      inventory = daily_inventories(:city_hall_bento_a_today)
      original_stock = inventory.stock

      submitted = { bento_a.id.to_s => { quantity: "5" } }
      form = OrderForm.new(location: @location, inventories: @inventories, submitted: submitted)

      form.save(employee: @employee)

      assert_equal original_stock + 5, inventory.reload.stock
    end

    test "save fails when no items have quantity" do
      form = OrderForm.new(location: @location, inventories: @inventories)

      assert_not form.save(employee: @employee)
      assert form.errors[:base].any?
    end

    test "save returns false and adds error on RecordInvalid" do
      bento_a = catalogs(:daily_bento_a)
      form = OrderForm.new(
        location: @location,
        inventories: @inventories,
        submitted: { bento_a.id.to_s => { quantity: "3" } }
      )

      # AdditionalOrder.create_with_inventory! をスタブして RecordInvalid を発生させる
      invalid_record = AdditionalOrder.new
      invalid_record.errors.add(:base, "テストエラー")
      error = ActiveRecord::RecordInvalid.new(invalid_record)

      AdditionalOrder.stub(:create_with_inventory!, ->(*) { raise error }) do
        assert_not form.save(employee: @employee)
        assert form.errors[:base].any?
        assert_includes form.errors[:base], "テストエラー"
      end
    end

    test "form_with_options returns correct url and method" do
      form = OrderForm.new(location: @location, inventories: @inventories)

      options = form.form_with_options
      assert_equal :post, options[:method]
      assert options[:url].include?("additional_orders")
    end
  end
end
