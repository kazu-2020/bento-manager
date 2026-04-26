# frozen_string_literal: true

module Sales
  class AnalysisSummary
    include CustomerTypePivot
    def initialize(location:, from:, to:)
      @location = location
      @from = from
      @to = to
    end

    # 顧客タイプ別の集計
    # @return [Hash] { staff: { quantity:, amount: }, citizen: { quantity:, amount: } }
    def summary_by_customer_type
      rows = Sale.completed
                 .at_location(location)
                 .in_period(from, to)
                 .joins(:items)
                 .group(:customer_type)
                 .pluck(
                   :customer_type,
                   Arel.sql("SUM(sale_items.quantity)"),
                   Arel.sql("SUM(sale_items.line_total)")
                 )

      rows.each_with_object(default_summary) do |(ct, qty, amount), hash|
        hash[ct.to_sym] = { quantity: qty.to_i, amount: amount.to_i }
      end
    end

    # 顧客タイプ別の商品ランキング
    # @return [Hash] { staff: [{ catalog_name:, quantity:, amount: }, ...], citizen: [...] }
    def ranking(limit: 5)
      %i[staff citizen].each_with_object({}) do |type, hash|
        hash[type] = Sale.completed
          .at_location(location)
          .in_period(from, to)
          .where(customer_type: type)
          .joins(items: :catalog)
          .where(catalogs: { category: :bento })
          .group("catalogs.name")
          .order(Arel.sql("SUM(sale_items.quantity) DESC"))
          .limit(limit)
          .pluck(
            Arel.sql("catalogs.name"),
            Arel.sql("SUM(sale_items.quantity)"),
            Arel.sql("SUM(sale_items.line_total)")
          )
          .map { |name, qty, amount| { catalog_name: name, quantity: qty.to_i, amount: amount.to_i } }
      end
    end

    # 商品×顧客タイプのクロス集計
    # @return [Array<Hash>] [{ catalog_name:, staff_quantity:, citizen_quantity:, total_quantity: }, ...]
    def cross_table
      rows = Sale.completed
        .at_location(location)
        .in_period(from, to)
        .joins(items: :catalog)
        .where(catalogs: { category: :bento })
        .group("catalogs.name", :customer_type)
        .pluck(
          Arel.sql("catalogs.name"),
          :customer_type,
          Arel.sql("SUM(sale_items.quantity)")
        )

      pivot_by_customer_type(rows)
    end

    private

    attr_reader :location, :from, :to

    def default_summary
      {
        staff: { quantity: 0, amount: 0 },
        citizen: { quantity: 0, amount: 0 }
      }
    end
  end
end
