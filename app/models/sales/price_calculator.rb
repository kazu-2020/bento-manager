# 価格計算 PORO
# カート内アイテムの価格ルール適用と割引計算を行う
module Sales
  class PriceCalculator
    # 価格計算を実行
    #
    # @param cart_items [Array<Hash>] カート内アイテム [{ catalog: Catalog, quantity: Integer }, ...]
    # @param discount_ids [Array<Integer>] 適用する割引の ID リスト
    # @return [Hash] 計算結果
    #   - :items_with_prices [Array<Hash>] 価格情報を付加したアイテム
    #   - :subtotal [Integer] 小計（割引前）
    #   - :discount_details [Array<Hash>] 割引詳細
    #   - :total_discount_amount [Integer] 割引合計
    #   - :final_total [Integer] 最終金額（割引後）
    def self.calculate(cart_items, discount_ids = [])
      return empty_result if cart_items.empty?

      # Step 1: 価格ルール適用（セット価格判定）
      items_with_prices = apply_pricing_rules(cart_items)

      # Step 2: 小計計算
      subtotal = items_with_prices.sum { |item| item[:unit_price] * item[:quantity] }

      # Step 3: 割引適用
      discount_result = apply_discounts(cart_items, discount_ids)

      # Step 4: 最終金額計算（0 以下にならないようにする）
      final_total = [ subtotal - discount_result[:total_discount_amount], 0 ].max

      {
        items_with_prices: items_with_prices,
        subtotal: subtotal,
        discount_details: discount_result[:discount_details],
        total_discount_amount: discount_result[:total_discount_amount],
        final_total: final_total
      }
    end

    # 価格ルールを適用してアイテムに価格情報を付加
    #
    # @param cart_items [Array<Hash>] カート内アイテム [{ catalog: Catalog, quantity: Integer }, ...]
    # @return [Array<Hash>] 価格情報を付加したアイテム
    def self.apply_pricing_rules(cart_items)
      result = []

      cart_items.each do |item|
        catalog = item[:catalog]

        # 価格ルールを検索
        pricing_rules = catalog.active_pricing_rules

        if pricing_rules.any? { |rule| rule.applicable?(cart_items) }
          # セット価格適用可能な場合
          result.concat(split_item_by_pricing_rule(item, cart_items, pricing_rules))
        else
          # 通常価格
          result << apply_regular_price(item)
        end
      end

      result
    end

    # 割引を適用
    #
    # @param cart_items [Array<Hash>] カート内アイテム [{ catalog: Catalog, quantity: Integer }, ...]
    # @param discount_ids [Array<Integer>] 適用する割引の ID リスト
    # @return [Hash] 割引適用結果
    #   - :discount_details [Array<Hash>] 各割引の詳細
    #   - :total_discount_amount [Integer] 割引合計
    def self.apply_discounts(cart_items, discount_ids)
      return { discount_details: [], total_discount_amount: 0 } if discount_ids.empty?

      discounts = Discount.active.where(id: discount_ids)
      discount_details = []
      total_discount_amount = 0

      discounts.each do |discount|
        applicable = discount.applicable?(cart_items)
        discount_amount = applicable ? discount.calculate_discount(cart_items) : 0

        discount_details << {
          discount_id: discount.id,
          discount_name: discount.name,
          discount_amount: discount_amount,
          applicable: applicable
        }

        total_discount_amount += discount_amount
      end

      {
        discount_details: discount_details,
        total_discount_amount: total_discount_amount
      }
    end

    def self.empty_result
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
    def self.split_item_by_pricing_rule(item, cart_items, pricing_rules)
      catalog = item[:catalog]
      quantity = item[:quantity]

      # 適用可能なルールから最大適用数量を計算
      max_bundle_quantity = pricing_rules
        .select { |rule| rule.applicable?(cart_items) }
        .map { |rule| rule.max_applicable_quantity(cart_items) }
        .max || 0

      bundle_quantity = [ quantity, max_bundle_quantity ].min
      regular_quantity = quantity - bundle_quantity

      result = []

      if bundle_quantity > 0
        bundle_price = CatalogPrice.current_price_by_kind(catalog.id, :bundle)
        result << item.merge(
          quantity: bundle_quantity,
          unit_price: bundle_price.price,
          catalog_price_id: bundle_price.id
        )
      end

      if regular_quantity > 0
        result << apply_regular_price(item.merge(quantity: regular_quantity))
      end

      result
    end

    # 通常価格を適用
    def self.apply_regular_price(item)
      catalog = item[:catalog]
      price = CatalogPrice.current_price_by_kind(catalog.id, :regular)

      # 通常価格がない場合は現在の価格にフォールバック
      price ||= catalog.current_price

      item.merge(
        unit_price: price.price,
        catalog_price_id: price.id
      )
    end

    private_class_method :empty_result, :split_item_by_pricing_rule, :apply_regular_price
  end
end
