# frozen_string_literal: true

module Sales
  class AnalysisSummary
    include CustomerTypePivot

    CUSTOMER_TYPES = %i[staff citizen].freeze

    # 当日を除くのは集計期間の都合ではなく売上分析そのものの性質である。
    # from / to に分解した入口は、その性質を持たない期間を素通しさせる
    def initialize(location:, period:)
      @location = location
      @period = period
    end

    # 顧客タイプ別の集計。販売が無かった顧客タイプも 0 個として並べ、
    # 呼び出し側にキーの有無を気にさせない
    # @return [Hash] { staff: 個数, citizen: 個数 }
    def summary_by_customer_type
      totals = bento_sales.group(:customer_type).sum("sale_items.quantity")

      CUSTOMER_TYPES.index_with { |type| totals[type.to_s].to_i }
    end

    # 顧客タイプ別の弁当ランキング
    # @return [Hash] { staff: [{ catalog_name:, quantity: }, ...], citizen: [...] }
    def ranking(limit: 5)
      CUSTOMER_TYPES.each_with_object({}) do |type, hash|
        hash[type] = bento_sales
          .where(customer_type: type)
          .group("catalogs.name")
          .order(Arel.sql("SUM(sale_items.quantity) DESC"))
          .limit(limit)
          .pluck("catalogs.name", Arel.sql("SUM(sale_items.quantity)"))
          .map { |name, qty| { catalog_name: name, quantity: qty.to_i } }
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
    # クロス集計表と合計が食い違ったように、また粒度が分かれる
    def bento_sales
      Sale.completed
          .at_location(location)
          .in_period(from, to)
          .joining_bento_items
    end
  end
end
