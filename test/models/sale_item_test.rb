require "test_helper"

class SaleItemTest < ActiveSupport::TestCase
  fixtures :locations, :employees, :sales, :catalogs, :catalog_prices

  test "validations" do
    @subject = SaleItem.new(
      sale: sales(:completed_sale),
      catalog: catalogs(:daily_bento_a),
      catalog_price: catalog_prices(:daily_bento_a_regular),
      quantity: 1,
      unit_price: 550,
      sold_at: Time.current
    )

    must validate_presence_of(:quantity)
    must validate_numericality_of(:quantity).is_greater_than(0)
    must validate_presence_of(:unit_price)
    must validate_numericality_of(:unit_price).is_greater_than(0)
    must validate_presence_of(:sold_at)
  end

  test "associations" do
    @subject = SaleItem.new

    must belong_to(:sale)
    must belong_to(:catalog)
    must belong_to(:catalog_price)
  end

  test "小計は単価と数量から自動計算される" do
    sale_item = SaleItem.new(
      sale: sales(:completed_sale),
      catalog: catalogs(:daily_bento_a),
      catalog_price: catalog_prices(:daily_bento_a_regular),
      quantity: 3,
      unit_price: 550,
      sold_at: Time.current
    )

    sale_item.valid?
    assert_equal 1650, sale_item.line_total

    sale_item.unit_price = nil
    sale_item.line_total = 100
    sale_item.valid?
    assert_equal 100, sale_item.line_total, "単価が未入力の場合は小計を上書きしない"
  end
end
