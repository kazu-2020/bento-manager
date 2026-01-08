require "test_helper"

class SaleItemTest < ActiveSupport::TestCase
  fixtures :locations, :employees, :catalogs, :catalog_prices, :daily_inventories, :sales, :sale_items

  # ===== Task 8.1: アソシエーションテスト =====

  test "belongs to sale" do
    sale_item = sale_items(:completed_sale_bento_a)
    assert_instance_of Sale, sale_item.sale
    assert_equal sales(:completed_sale), sale_item.sale
  end

  test "belongs to catalog" do
    sale_item = sale_items(:completed_sale_bento_a)
    assert_instance_of Catalog, sale_item.catalog
    assert_equal catalogs(:daily_bento_a), sale_item.catalog
  end

  test "belongs to catalog_price" do
    sale_item = sale_items(:completed_sale_bento_a)
    assert_instance_of CatalogPrice, sale_item.catalog_price
    assert_equal catalog_prices(:daily_bento_a_regular), sale_item.catalog_price
  end

  test "sale has_many items" do
    sale = sales(:completed_sale)
    assert_includes sale.items, sale_items(:completed_sale_bento_a)
  end

  # ===== Task 8.2: バリデーションテスト =====

  test "quantity must be present" do
    sale_item = build_valid_sale_item
    sale_item.quantity = nil
    assert_not sale_item.valid?
    assert_includes sale_item.errors[:quantity], "を入力してください"
  end

  test "quantity must be greater than 0" do
    sale_item = build_valid_sale_item
    sale_item.quantity = 0
    assert_not sale_item.valid?
    assert_includes sale_item.errors[:quantity], "は0より大きい値にしてください"

    sale_item.quantity = -1
    assert_not sale_item.valid?
    assert_includes sale_item.errors[:quantity], "は0より大きい値にしてください"
  end

  test "unit_price must be present" do
    sale_item = build_valid_sale_item
    sale_item.unit_price = nil
    assert_not sale_item.valid?
    assert_includes sale_item.errors[:unit_price], "を入力してください"
  end

  test "unit_price must be greater than 0" do
    sale_item = build_valid_sale_item
    sale_item.unit_price = 0
    assert_not sale_item.valid?
    assert_includes sale_item.errors[:unit_price], "は0より大きい値にしてください"

    sale_item.unit_price = -1
    assert_not sale_item.valid?
    assert_includes sale_item.errors[:unit_price], "は0より大きい値にしてください"
  end

  test "sold_at must be present" do
    sale_item = build_valid_sale_item
    sale_item.sold_at = nil
    assert_not sale_item.valid?
    assert_includes sale_item.errors[:sold_at], "を入力してください"
  end

  # ===== Task 8.2: line_total 計算テスト =====

  test "calculate_line_total sets line_total from unit_price and quantity" do
    sale_item = build_valid_sale_item
    sale_item.unit_price = 550
    sale_item.quantity = 3
    sale_item.line_total = nil

    sale_item.valid?

    assert_equal 1650, sale_item.line_total
  end

  test "calculate_line_total does not overwrite line_total if unit_price is nil" do
    sale_item = build_valid_sale_item
    sale_item.unit_price = nil
    sale_item.quantity = 3
    sale_item.line_total = 100

    sale_item.valid?

    assert_equal 100, sale_item.line_total
  end

  # Note: 在庫減算テストは Sales::RecorderTest に移動

  private

  # バリデーションテスト用の有効な SaleItem を構築（保存しない）
  def build_valid_sale_item
    SaleItem.new(
      sale: sales(:completed_sale),
      catalog: catalogs(:daily_bento_a),
      catalog_price: catalog_prices(:daily_bento_a_regular),
      quantity: 1,
      unit_price: 550,
      line_total: 550,
      sold_at: Time.current
    )
  end
end
