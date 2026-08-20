module SaleTestHelper
  def create_sale(location:, customer_type:, sale_datetime:, status: :completed, voided_at: nil, voided_by_employee: nil)
    Sale.create!(
      location:,
      customer_type:,
      sale_datetime:,
      status:,
      total_amount: 550,
      final_amount: 550,
      employee: employees(:verified_employee),
      voided_at:,
      voided_by_employee:
    )
  end

  # 商品は catalog_price だけで決まる。商品と単価を別々に渡せると、
  # サラダを弁当の単価で売った販売行が作れてしまう
  def create_sale_item(sale:, quantity:, catalog_price: catalog_prices(:daily_bento_a_regular))
    SaleItem.create!(
      sale:,
      catalog: catalog_price.catalog,
      catalog_price:,
      quantity:,
      unit_price: catalog_price.price,
      sold_at: sale.sale_datetime
    )
  end
end
