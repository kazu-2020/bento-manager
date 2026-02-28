require "test_helper"

class LocationDailySalesQuantityTest < ActiveSupport::TestCase
  include SaleTestHelper

  fixtures :locations, :employees, :catalogs, :catalog_prices

  test "販売先の直近1ヶ月の日次販売個数が顧客区分ごとに集計される" do
    location = locations(:city_hall)
    sale_date = 3.days.ago

    staff_sale = create_sale(location:, customer_type: :staff, sale_datetime: sale_date)
    create_sale_item(sale: staff_sale, quantity: 2)

    citizen_sale = create_sale(location:, customer_type: :citizen, sale_datetime: sale_date)
    create_sale_item(sale: citizen_sale, quantity: 3)

    result = location.daily_sales_quantity

    assert_equal 2, result[[ sale_date.to_date.to_s, "staff" ]]
    assert_equal 3, result[[ sale_date.to_date.to_s, "citizen" ]]
  end

  test "取り消された販売は集計に含まれない" do
    location = locations(:city_hall)
    sale_date = 3.days.ago

    voided_sale = create_sale(location:, customer_type: :staff, sale_datetime: sale_date,
                              status: :voided, voided_at: Time.current, voided_by_employee: employees(:owner_employee))
    create_sale_item(sale: voided_sale, quantity: 5)

    completed_sale = create_sale(location:, customer_type: :staff, sale_datetime: sale_date)
    create_sale_item(sale: completed_sale, quantity: 1)

    result = location.daily_sales_quantity

    assert_equal 1, result[[ sale_date.to_date.to_s, "staff" ]]
  end

  test "1ヶ月より前の販売は集計に含まれない" do
    location = locations(:city_hall)

    old_sale = create_sale(location:, customer_type: :staff, sale_datetime: 2.months.ago)
    create_sale_item(sale: old_sale, quantity: 10)

    result = location.daily_sales_quantity

    assert_nil result[[ 2.months.ago.to_date.to_s, "staff" ]]
  end

  test "販売データがない販売先は空のハッシュを返す" do
    location = Location.create!(name: "新規販売先", status: :active)

    assert_empty location.daily_sales_quantity
  end
end
