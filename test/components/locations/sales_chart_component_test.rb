# frozen_string_literal: true

require "test_helper"

class Locations::SalesChartComponentTest < ViewComponent::TestCase
  include SaleTestHelper

  fixtures :locations, :employees, :catalogs, :catalog_prices

  test "販売データがある場合はグラフ要素がレンダリングされる" do
    location = locations(:city_hall)
    sale = create_sale(location:, customer_type: :staff, sale_datetime: 3.days.ago)
    create_sale_item(sale:, quantity: 2)

    result = render_inline(Locations::SalesChart::Component.new(location:))

    assert result.css("[id^='chart-']").present?
  end

  test "chart_data に職員・市民の2系列と直近1ヶ月分の全日データが含まれる" do
    location = locations(:city_hall)

    component = Locations::SalesChart::Component.new(location:)
    render_inline(component)
    data = component.chart_data

    assert_equal 2, data.size
    assert_equal "職員", data[0][:name]
    assert_equal "市民", data[1][:name]

    expected_days = (1.month.ago.to_date..Date.current).count
    assert_equal expected_days, data[0][:data].size
    assert_equal expected_days, data[1][:data].size
  end
end
