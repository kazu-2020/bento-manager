# frozen_string_literal: true

require "test_helper"

class Locations::SalesChartComponentTest < ViewComponent::TestCase
  include SaleTestHelper

  fixtures :employees, :catalogs, :catalog_prices

  setup do
    # 集計対象を自分が作ったデータだけに限定する
    @location = Location.create!(name: "グラフテスト販売先", status: :active)
  end

  test "販売データは販売日の職員系列に反映される" do
    sale_date = 3.days.ago
    sale = create_sale(location: @location, customer_type: :staff, sale_datetime: sale_date)
    create_sale_item(sale:, quantity: 2)

    component = Locations::SalesChart::Component.new(location: @location)
    result = render_inline(component)

    assert_predicate result.css("[id^='chart-']"), :present?
    assert_equal 2, component.chart_data[0][:data][sale_date.to_date.strftime("%-m/%-d")]
  end

  test "chart_data に職員・市民の2系列と直近1ヶ月分の全日データが含まれる" do
    component = Locations::SalesChart::Component.new(location: @location)
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
