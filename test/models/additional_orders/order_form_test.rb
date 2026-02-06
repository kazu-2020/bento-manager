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

    test "在庫一覧からフォーム項目を構築し入力数量で絞り込める" do
      form = OrderForm.new(location: @location, inventories: @inventories)

      assert form.items.any?
      form.items.each do |item|
        assert_kind_of AdditionalOrders::OrderItem, item
        assert item.catalog_name.present?
        assert_equal 0, item.quantity
      end
      assert_equal @inventories.sum(&:available_stock), form.total_available_stock

      bento_a = catalogs(:daily_bento_a)
      submitted = { bento_a.id.to_s => { quantity: "5" } }
      form_with_input = OrderForm.new(location: @location, inventories: @inventories, submitted: submitted)

      assert_equal 1, form_with_input.items_with_quantity.count
      assert_equal bento_a.id, form_with_input.items_with_quantity.first.catalog_id
      assert_equal 5, form_with_input.items_with_quantity.first.quantity
    end

    test "追加発注を保存すると注文数分だけ在庫が増える" do
      bento_a = catalogs(:daily_bento_a)
      bento_b = catalogs(:daily_bento_b)
      inventory = daily_inventories(:city_hall_bento_a_today)
      original_stock = inventory.stock

      submitted = {
        bento_a.id.to_s => { quantity: "3" },
        bento_b.id.to_s => { quantity: "2" }
      }
      form = OrderForm.new(location: @location, inventories: @inventories, submitted: submitted)

      assert_difference "AdditionalOrder.count", 2 do
        assert form.save(employee: @employee)
      end

      assert_equal 2, form.created_count
      assert_equal original_stock + 3, inventory.reload.stock
    end

    test "発注数が未入力の場合や登録エラー時は保存されない" do
      form = OrderForm.new(location: @location, inventories: @inventories)
      assert_not form.save(employee: @employee)
      assert form.errors[:base].any?

      bento_a = catalogs(:daily_bento_a)
      form_with_input = OrderForm.new(
        location: @location,
        inventories: @inventories,
        submitted: { bento_a.id.to_s => { quantity: "3" } }
      )

      invalid_record = AdditionalOrder.new
      invalid_record.errors.add(:base, "テストエラー")
      error = ActiveRecord::RecordInvalid.new(invalid_record)

      AdditionalOrder.stub(:create_with_inventory!, ->(*) { raise error }) do
        assert_not form_with_input.save(employee: @employee)
        assert_includes form_with_input.errors[:base], "テストエラー"
      end
    end
  end
end
