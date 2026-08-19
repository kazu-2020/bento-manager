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

  def create_sale_item(sale:, quantity:, catalog: catalogs(:daily_bento_a), catalog_price: catalog_prices(:daily_bento_a_regular), unit_price: 550)
    SaleItem.create!(
      sale:,
      catalog:,
      catalog_price:,
      quantity:,
      unit_price:,
      sold_at: sale.sale_datetime
    )
  end
end
