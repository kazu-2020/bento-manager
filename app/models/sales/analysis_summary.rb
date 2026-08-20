# frozen_string_literal: true

module Sales
  class AnalysisSummary
    include CustomerTypePivot

    # 当日を除くのは集計期間の都合ではなく売上分析そのものの性質である。
    # from / to に分解した入口は、その性質を持たない期間を素通しさせる
    def initialize(location:, period:)
      @location = location
      @period = period
    end

    # 顧客タイプ別の集計
    # @return [Hash] { staff: { quantity:, amount: }, citizen: { quantity:, amount: } }
    def summary_by_customer_type
      rows = bento_sales
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

    # 顧客タイプ別の弁当ランキング
    # @return [Hash] { staff: [{ catalog_name:, quantity:, amount: }, ...], citizen: [...] }
    def ranking(limit: 5)
      %i[staff citizen].each_with_object({}) do |type, hash|
        hash[type] = bento_sales
          .where(customer_type: type)
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

    # 弁当×顧客タイプのクロス集計
    # @return [Array<Hash>] [{ catalog_name:, staff_quantity:, citizen_quantity:, total_quantity: }, ...]
    def cross_table
      rows = bento_sales
        .group("catalogs.name", :customer_type)
        .pluck(
          Arel.sql("catalogs.name"),
          :customer_type,
          Arel.sql("SUM(sale_items.quantity)")
        )

      pivot_by_customer_type(rows)
    end

    private

    attr_reader :location, :period

    delegate :from, :to, to: :period, private: true

    # 売上分析が数える販売行。3 つの集計はこの母集合を共有する。
    # 集計ごとに条件を書くと、かつてサマリーだけがサイドメニューを含んで
    # クロス集計表と合計が食い違ったように、また粒度が分かれる。
    # 1 行は販売ではなく販売 × 弁当なので、件数を数える用途には使えない
    def bento_sales
      Sale.completed
          .at_location(location)
          .in_period(from, to)
          .joins(items: :catalog)
          .merge(Catalog.bento)
    end

    def default_summary
      {
        staff: { quantity: 0, amount: 0 },
        citizen: { quantity: 0, amount: 0 }
      }
    end
  end
end
