# 返品・返金処理 PORO
# 元の Sale を void し、残す商品で新規 Sale を作成し、差額を Refund に記録する
module Sales
  class Refunder
    # 返品・返金処理を実行
    #
    # @param sale [Sale] 元の販売レコード
    # @param remaining_items [Array<Hash>] 残す商品のリスト
    #   - :catalog [Catalog] 商品
    #   - :quantity [Integer] 数量
    # @param reason [String] 返金理由
    # @param employee [Employee] 返金処理担当者
    # @return [Hash] 処理結果
    #   - :success [Boolean] 成功/失敗
    #   - :refund [Refund] 作成された Refund レコード
    #   - :corrected_sale [Sale, nil] 作成された新規 Sale（全額返金の場合は nil）
    #   - :refund_amount [Integer] 返金額
    # @raise [Sale::AlreadyVoidedError] 既に voided の場合
    # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
    def process(sale:, remaining_items:, reason:, employee:)
      Sale.transaction do
        sale.void!(reason: reason, voided_by: employee)
        restore_inventory(sale)

        corrected_sale = create_corrected_sale(sale, remaining_items, employee)
        refund_amount = calculate_refund_amount(sale, corrected_sale)
        refund = create_refund(sale, corrected_sale, refund_amount, reason, employee)

        {
          success: true,
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

    # 残す商品で新規 Sale を作成
    #
    # @param original_sale [Sale] 元の販売レコード
    # @param remaining_items [Array<Hash>] 残す商品のリスト
    # @param employee [Employee] 販売員
    # @return [Sale, nil] 作成された Sale（全額返金の場合は nil）
    def create_corrected_sale(original_sale, remaining_items, employee)
      return nil if remaining_items.empty?

      Sales::Recorder.new.record(
        {
          location: original_sale.location,
          customer_type: original_sale.customer_type,
          employee: employee,
          corrected_from_sale_id: original_sale.id
        },
        remaining_items,
        discount_ids: extract_discount_ids(original_sale)
      )
    end

    # 元の Sale から適用されていた割引 ID を抽出
    #
    # @param sale [Sale] 元の販売レコード
    # @return [Array<Integer>] 割引 ID リスト
    def extract_discount_ids(sale)
      sale.sale_discounts.pluck(:discount_id)
    end

    # 返金額を計算
    #
    # @param original_sale [Sale] 元の販売レコード
    # @param corrected_sale [Sale, nil] 新規販売レコード
    # @return [Integer] 返金額
    def calculate_refund_amount(original_sale, corrected_sale)
      original_sale.final_amount - (corrected_sale&.final_amount || 0)
    end

    # Refund レコードを作成
    #
    # @param original_sale [Sale] 元の販売レコード
    # @param corrected_sale [Sale, nil] 新規販売レコード
    # @param amount [Integer] 返金額
    # @param reason [String] 返金理由
    # @param employee [Employee] 返金処理担当者
    # @return [Refund]
    def create_refund(original_sale, corrected_sale, amount, reason, employee)
      Refund.create!(
        original_sale: original_sale,
        corrected_sale: corrected_sale,
        employee: employee,
        refund_datetime: Time.current,
        amount: amount,
        reason: reason
      )
    end
  end
end
