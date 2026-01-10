# 価格計算 PORO
# カート内アイテムの価格ルール適用と割引計算を行う
module Sales
  class PriceCalculator
    # 必要な価格が存在しない場合に発生する例外
    class MissingPriceError < StandardError
      attr_reader :missing_prices

      def initialize(missing_prices)
        @missing_prices = missing_prices
        messages = missing_prices.map do |mp|
          "商品「#{mp[:catalog_name]}」に価格種別「#{mp[:price_kind]}」の価格が設定されていません"
        end
        super("価格設定エラー: #{messages.join('; ')}")
      end
    end

    attr_reader :cart_items, :discount_ids, :calculation_time

    # @param cart_items [Array<Hash>] カート内アイテム [{ catalog: Catalog, quantity: Integer }, ...]
    # @param discount_ids [Array<Integer>] 適用する割引の ID リスト
    def initialize(cart_items, discount_ids: [])
      @cart_items = cart_items
      @discount_ids = discount_ids
      @calculation_time = Time.current
    end

    # 価格計算を実行
    #
    # @return [Hash] 計算結果
    #   - :items_with_prices [Array<Hash>] 価格情報を付加したアイテム
    #   - :subtotal [Integer] 小計（割引前）
    #   - :discount_details [Array<Hash>] 割引詳細
    #   - :total_discount_amount [Integer] 割引合計
    #   - :final_total [Integer] 最終金額（割引後）
    def calculate
      return empty_result if cart_items.empty?

      # Step 1: 価格存在検証（必要な価格がすべて設定されているかチェック）
      validate_required_prices!

      # Step 2: 価格ルール適用（セット価格判定）
      items_with_prices = apply_pricing_rules

      # Step 3: 小計計算
      subtotal = items_with_prices.sum { |item| item[:unit_price] * item[:quantity] }

      # Step 4: 割引適用
      discount_result = apply_discounts

      # Step 5: 最終金額計算
      # NOTE: ビジネスルール上 final_total = 0 になるケースは発生しない想定だが、
      #       防御的なセーフティネットとして 0 以下にならないようにしている
      final_total = [ subtotal - discount_result[:total_discount_amount], 0 ].max

      {
        items_with_prices: items_with_prices,
        subtotal: subtotal,
        discount_details: discount_result[:discount_details],
        total_discount_amount: discount_result[:total_discount_amount],
        final_total: final_total
      }
    end

    private

    # 価格ルールを適用してアイテムに価格情報を付加
    #
    # @return [Array<Hash>] 価格情報を付加したアイテム
    def apply_pricing_rules
      cart_items.flat_map do |item|
        pricing_rules = item[:catalog].active_pricing_rules_at(calculation_time.to_date)
        applicable_rules = pricing_rules.select { |rule| rule.applicable?(cart_items) }

        if applicable_rules.any?
          split_item_by_pricing_rule(item, applicable_rules)
        else
          [ apply_regular_price(item) ]
        end
      end
    end

    # 割引を適用
    #
    # @return [Hash] 割引適用結果
    #   - :discount_details [Array<Hash>] 各割引の詳細
    #   - :total_discount_amount [Integer] 割引合計
    def apply_discounts
      return { discount_details: [], total_discount_amount: 0 } if discount_ids.empty?

      discount_details = Discount.active.where(id: discount_ids).map do |discount|
        discount_amount = discount.calculate_discount(cart_items)

        {
          discount_id: discount.id,
          discount_name: discount.name,
          discount_amount: discount_amount,
          applicable: discount_amount > 0
        }
      end

      {
        discount_details: discount_details,
        total_discount_amount: discount_details.sum { |d| d[:discount_amount] }
      }
    end

    def empty_result
      {
        items_with_prices: [],
        subtotal: 0,
        discount_details: [],
        total_discount_amount: 0,
        final_total: 0
      }
    end

    # アイテムを価格ルールに基づいて分割
    # 例: 弁当1個 + サラダ3個 → サラダ1個@150円 + サラダ2個@250円
    #
    # @param item [Hash] カートアイテム
    # @param applicable_rules [Array<PricingRule>] 適用可能な価格ルール（事前にフィルタ済み）
    def split_item_by_pricing_rule(item, applicable_rules)
      selected_rule = applicable_rules.max_by { |rule| rule.max_applicable_quantity(cart_items) }
      max_quantity = selected_rule.max_applicable_quantity(cart_items)

      bundle_quantity = [ item[:quantity], max_quantity ].min
      regular_quantity = item[:quantity] - bundle_quantity

      result = []
      result << build_bundle_price_item(item, selected_rule, bundle_quantity) if bundle_quantity > 0
      result << apply_regular_price(item.merge(quantity: regular_quantity)) if regular_quantity > 0
      result
    end

    # バンドル価格アイテムを構築
    def build_bundle_price_item(item, rule, quantity)
      bundle_price = item[:catalog].price_by_kind(rule.price_kind.to_sym, at: calculation_time)

      # 価格が存在しない場合は通常価格にフォールバック
      return apply_regular_price(item.merge(quantity: quantity)) if bundle_price.nil?

      item.merge(
        quantity: quantity,
        unit_price: bundle_price.price,
        catalog_price_id: bundle_price.id
      )
    end

    # 通常価格を適用
    def apply_regular_price(item)
      catalog = item[:catalog]
      price = catalog.price_by_kind(:regular, at: calculation_time)

      item.merge(
        unit_price: price.price,
        catalog_price_id: price.id
      )
    end

    # 必要な価格がすべて設定されているか検証
    # @raise [MissingPriceError] 価格が設定されていない商品がある場合
    def validate_required_prices!
      validator = Catalogs::PriceValidator.new(at: calculation_time)

      missing = cart_items.flat_map do |item|
        catalog = item[:catalog]

        determine_required_price_kinds(catalog)
          .reject { |kind| validator.price_exists?(catalog, kind) }
          .map { |kind| { catalog_id: catalog.id, catalog_name: catalog.name, price_kind: kind.to_s } }
      end

      raise MissingPriceError.new(missing) if missing.any?
    end

    # 商品に必要な価格種別を決定
    # @param catalog [Catalog] 商品
    # @return [Array<Symbol>] 必要な価格種別
    def determine_required_price_kinds(catalog)
      applicable_rule_kinds = catalog
        .active_pricing_rules_at(calculation_time.to_date)
        .select { |rule| rule.applicable?(cart_items) }
        .map { |rule| rule.price_kind.to_sym }

      [ :regular, *applicable_rule_kinds ].uniq
    end
  end
end
