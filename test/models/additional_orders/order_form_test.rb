# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module AdditionalOrders
  class OrderFormTest < ActiveSupport::TestCase
    fixtures :locations, :catalogs, :daily_inventories, :employees

    setup do
      @location = locations(:city_hall)
      @employee = employees(:verified_employee)
      @catalogs = Catalog.bento.available.order(:kana)
      @stock_map = @location.today_inventories
                            .where(catalog_id: @catalogs.select(:id))
                            .to_h { |inv| [ inv.catalog_id, inv.available_stock ] }
    end

    test "全弁当カタログからフォーム項目を構築し入力数量で絞り込める" do
      form = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map)

      assert form.items.any?
      form.items.each do |item|
        assert_kind_of AdditionalOrders::OrderItem, item
        assert item.catalog_name.present?
        assert_equal 0, item.quantity
      end
      assert_equal @stock_map.values.sum, form.total_available_stock

      bento_a = catalogs(:daily_bento_a)
      submitted = { bento_a.id.to_s => { quantity: "5" } }
      form_with_input = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map, submitted: submitted)

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
      form = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map, submitted: submitted)

      assert_difference "AdditionalOrder.count", 2 do
        assert form.save(employee: @employee)
      end

      assert_equal 2, form.created_count
      assert_equal original_stock + 3, inventory.reload.stock
    end

    test "発注数が未入力の場合や登録エラー時は保存されない" do
      form = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map)
      assert_not form.save(employee: @employee)
      assert form.errors[:base].any?

      bento_a = catalogs(:daily_bento_a)
      form_with_input = OrderForm.new(
        location: @location,
        catalogs: @catalogs,
        stock_map: @stock_map,
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

    test "在庫登録済みと未登録のアイテムを分類できる" do
      form = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map)

      form.inventory_items.each do |item|
        assert item.in_inventory?, "#{item.catalog_name} は在庫登録済みであるべき"
      end

      form.non_inventory_items.each do |item|
        assert_not item.in_inventory?, "#{item.catalog_name} は在庫未登録であるべき"
      end

      assert_equal form.items.size, form.inventory_items.size + form.non_inventory_items.size
    end

    test "検索クエリで商品の表示・非表示を判定できる" do
      form_without_query = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map)
      form_without_query.items.each do |item|
        assert form_without_query.visible?(item), "検索クエリなしでは全商品が表示される"
      end

      form_with_query = OrderForm.new(
        location: @location, catalogs: @catalogs, stock_map: @stock_map,
        search_query: "弁当A"
      )
      bento_a = form_with_query.items.find { |i| i.catalog_name == "日替わり弁当A" }
      bento_b = form_with_query.items.find { |i| i.catalog_name == "日替わり弁当B" }

      assert form_with_query.visible?(bento_a)
      assert_not form_with_query.visible?(bento_b)
    end

    test "在庫未登録の弁当を追加発注すると在庫レコードが自動作成される" do
      unlisted = Catalog.create!(name: "トルコライスカレー", kana: "トルコライスカレー", category: :bento)
      catalogs = Catalog.bento.available.order(:kana)
      stock_map = @location.today_inventories
                           .where(catalog_id: catalogs.select(:id))
                           .to_h { |inv| [ inv.catalog_id, inv.available_stock ] }

      assert_not stock_map.key?(unlisted.id)

      submitted = { unlisted.id.to_s => { quantity: "3" } }
      form = OrderForm.new(location: @location, catalogs: catalogs, stock_map: stock_map, submitted: submitted)

      assert_difference [ "AdditionalOrder.count", "DailyInventory.count" ], 1 do
        assert form.save(employee: @employee)
      end

      created_inventory = @location.today_inventories.find_by!(catalog_id: unlisted.id)
      assert_equal 3, created_inventory.stock
    end

    test "form_state_options が正しいURLとメソッドを返す" do
      form = OrderForm.new(location: @location, catalogs: @catalogs, stock_map: @stock_map)
      options = form.form_state_options

      assert_equal :post, options[:method]
      assert_equal "/pos/locations/#{@location.id}/additional_orders/form_state", options[:url]
    end
  end
end
