# 返品・返金・差額精算処理 PORO
# 元の Sale を void し、修正後の商品で新規 Sale を作成し、差額を Refund に記録する
module Sales
  class Refunder
    # 返品・返金・差額精算処理を実行
    #
    # @param sale [Sale] 元の販売レコード
    # @param corrected_items [Array<Hash>] 修正後の商品リスト（残存商品 + 追加商品）
    #   - :catalog [Catalog] 商品
    #   - :quantity [Integer] 数量
    # @param employee [Employee] 処理担当者
    # @return [Hash] 処理結果
    #   - :refund [Refund] 作成された Refund レコード
    #   - :corrected_sale [Sale, nil] 作成された新規 Sale（全額返金の場合は nil）
    #   - :refund_amount [Integer] 差額（正=返金、負=追加徴収、0=等価交換）
    # @raise [Sale::AlreadyVoidedError] 既に voided の場合
    # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
    def process(sale:, corrected_items:, employee:, discount_quantities: nil)
      Sale.transaction do
        sale.void!(voided_by: employee)
        restore_inventory(sale)

        corrected_sale = create_corrected_sale(sale, corrected_items, employee, discount_quantities)
        refund_amount = calculate_refund_amount(sale, corrected_sale)
        refund = Refund.create!(
          original_sale: sale,
          corrected_sale: corrected_sale,
          employee: employee,
          refund_datetime: Time.current,
          amount: refund_amount
        )

        {
          refund: refund,
          corrected_sale: corrected_sale,
          refund_amount: refund_amount
        }
      end
    end

    private

    # 在庫を復元（元の Sale の全アイテム分）
    #
    # @param sale [Sale] 元の販売レコード
    def restore_inventory(sale)
      sale.items.each do |sale_item|
        inventory = find_inventory(sale, sale_item)
        inventory.increment_stock!(sale_item.quantity)
      end
    end

    # 対応する DailyInventory を検索
    #
    # @param sale [Sale] 販売レコード
    # @param sale_item [SaleItem] 販売明細
    # @return [DailyInventory]
    def find_inventory(sale, sale_item)
      DailyInventory.find_by!(
        location_id: sale.location_id,
        catalog_id: sale_item.catalog_id,
        inventory_date: sale_item.sold_at.to_date
      )
    end

    # 修正後の商品で新規 Sale を作成
    #
    # @param original_sale [Sale] 元の販売レコード
    # @param corrected_items [Array<Hash>] 修正後の商品リスト
    # @param employee [Employee] 販売員
    # @return [Sale, nil] 作成された Sale（全額返金の場合は nil）
    def create_corrected_sale(original_sale, corrected_items, employee, discount_quantities)
      return nil if corrected_items.empty?

      effective_discount_quantities = discount_quantities || extract_discount_quantities(original_sale)

      Sales::Recorder.new.record(
        {
          location: original_sale.location,
          customer_type: original_sale.customer_type,
          employee: employee,
          corrected_from_sale_id: original_sale.id
        },
        corrected_items,
        discount_quantities: effective_discount_quantities
      )
    end

    # 元の Sale から適用されていた割引 ID と枚数を抽出
    #
    # @param sale [Sale] 元の販売レコード
    # @return [Hash{Integer => Integer}] 割引 ID と枚数の Hash
    def extract_discount_quantities(sale)
      sale.sale_discounts.pluck(:discount_id, :quantity).to_h
    end

    # 差額を計算（正=返金、負=追加徴収、0=等価交換）
    #
    # @param original_sale [Sale] 元の販売レコード
    # @param corrected_sale [Sale, nil] 新規販売レコード
    # @return [Integer] 差額
    def calculate_refund_amount(original_sale, corrected_sale)
      original_sale.final_amount - (corrected_sale&.final_amount || 0)
    end
  end
end
