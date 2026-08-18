# frozen_string_literal: true

require "test_helper"

class SalesHistories::TransactionTableComponentTest < ViewComponent::TestCase
  include SaleTestHelper

  fixtures :employees, :catalogs, :catalog_prices

  setup do
    @location = Location.create!(name: "取引一覧テスト販売先", status: :active)
  end

  # Sale#total_amount は 0 以上のバリデーションが掛かっているため、負値の表示は起こり得ない
  test "取引の金額を通貨表記で表示する" do
    sale = create_sale(location: @location, customer_type: :staff, sale_datetime: Time.current)
    create_sale_item(sale: sale, quantity: 1)

    result = render_inline(SalesHistories::TransactionTable::Component.new(sales: [ sale ]))

    assert_includes result.to_html, "¥550"
  end
end
