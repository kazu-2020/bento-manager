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
    # @raise [Sale::NotTodaysSaleError] 当日以外の販売の場合
    # @raise [ActiveRecord::RecordInvalid] バリデーションエラー時
    # @raise [ActiveRecord::RecordNotFound] 復元先の DailyInventory レコードが見つからない場合
    def process(sale:, corrected_items:, employee:, discount_quantities: nil)
      # 在庫の復元は元の販売日、修正後の販売の在庫減算は当日を基準にする。
      # 当日以外の販売を通すと両日の在庫と日別売上が同時にずれるため、
      # 副作用を起こす前に断る（コントローラのガードとは別に、経路を問わず塞ぐ）
      raise Sale::NotTodaysSaleError, "当日以外の販売は差額精算できません" unless sale.sold_today?

      # void! はメモリ上の status しか見ないため、取り消し前に読まれた Sale を
      # 渡されると二重に通る（Refund が 2 件でき、在庫も二度戻る）。行を読み直して
      # からトランザクションに入り、判定を渡されたインスタンスに委ねない
      sale.with_lock do
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
    # 明細ごとに引き直すのは ADR-0003 決定 2 の前提。トランザクション内で引き直す
    # から、bulk_recreate が当日分を作り直した後でも消えた行を掴んだまま更新する
    # 経路が無い。まとめて 1 回で引けば明細 N 件につき N-1 本減るが、残り 2 本
    # （with_lock の reload と UPDATE）は外せないので、削減幅に見合わない
    #
    # @param sale [Sale] 元の販売レコード
    def restore_inventory(sale)
      sale.items.each do |sale_item|
        inventory = DailyInventory.find_for!(
          location: sale.location_id,
          catalog: sale_item.catalog_id,
          date: sale_item.sold_at.to_date
        )
        inventory.increment_stock!(sale_item.quantity)
      end
    end

    # 修正後の商品で新規 Sale を作成
    #
    # @param original_sale [Sale] 元の販売レコード
    # @param corrected_items [Array<Hash>] 修正後の商品リスト
    # @param employee [Employee] 販売員
    # @return [Sale, nil] 作成された Sale（全額返金の場合は nil）
    def create_corrected_sale(original_sale, corrected_items, employee, discount_quantities)
      return nil if corrected_items.empty?

      Sales::Recorder.new.record(
        {
          location: original_sale.location,
          customer_type: original_sale.customer_type,
          employee: employee
        },
        corrected_items,
        discount_quantities: discount_quantities || original_sale.applied_discount_quantities
      )
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
