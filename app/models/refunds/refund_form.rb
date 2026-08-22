# frozen_string_literal: true

module Refunds
  class RefundForm
    # 陳列カテゴリに載らない商品が数量入力の母集合に現れたときに投げる（詳細は verify_displayable）
    class UndisplayableCategoryError < StandardError; end

    include ActiveModel::Model
    include Rails.application.routes.url_helpers

    include ::GhostForms::SubmissionReadable

    # submitted のどの位置に何が来るかの宣言（GhostForms::ParamsFilter が使う）
    SUBMITTED_PARAMS_SHAPE = { collection_keys: %w[corrected coupon] }.freeze

    attr_reader :sale, :location, :corrected_quantities, :coupon_quantities, :inventories

    validate :at_least_one_change

    # submitted は GhostForms::Submission。初回描画は元の販売から初期値を作るので、
    # 未送信と壊れた送信を見分ける必要がある（理由は GhostForms::Submission）
    def initialize(sale:, location:, inventories: [], submitted: ::GhostForms::Submission.absent)
      @sale = sale
      @location = location
      @inventories = inventories
      @submitted = submitted
      @corrected_quantities = build_corrected_quantities
      @coupon_quantities = build_coupon_quantities
    end

    def corrected_items
      @corrected_items ||= build_corrected_items
    end

    def corrected_items_for_refunder
      @corrected_items_for_refunder ||= corrected_quantities.filter_map do |catalog_id, qty|
        next if qty <= 0
        catalog = find_catalog(catalog_id)
        next unless catalog
        { catalog: catalog, quantity: qty }
      end
    end

    def discount_quantities_for_refunder
      coupon_quantities.select { |_, qty| qty > 0 }
    end

    # 現在値と初期値は同じ母集合で組まれているので、単純な突き合わせで足りる
    def has_any_changes?
      corrected_quantities != original_corrected_quantities ||
        coupon_quantities != original_coupon_quantities
    end

    # 修正後の金額と差額。3 つの状態は Preview の奥に畳んであるので、ここでは分岐しない
    def preview
      @preview ||= Preview.new(
        sale: sale,
        items: corrected_items_for_refunder,
        discount_quantities: discount_quantities_for_refunder,
        changed: has_any_changes?
      )
    end

    def total_corrected_bento_quantity
      @total_corrected_bento_quantity ||= bento_corrected_items.sum(&:quantity)
    end

    def bento_corrected_items
      @bento_corrected_items ||= corrected_items.select(&:bento?)
    end

    def side_menu_corrected_items
      @side_menu_corrected_items ||= corrected_items.select(&:side_menu?)
    end

    # 配列で返す。relation のままだと any? が未ロードのときに存在確認だけの問い合わせを
    # 1 本撃つ。いまロード済みなのは初期化が先に map(&:id) を通るからにすぎない
    def available_discounts
      @available_discounts ||= Discount.active_with_discountable.to_a
    end

    def form_with_options
      { url: pos_location_refunds_path(location), method: :post }
    end

    def form_state_options
      { url: pos_location_refunds_form_state_path(location), method: :post }
    end

    private

    # 届いたキーだけの疎なハッシュ。そのまま外へ出さず、build_* が母集合に対して埋め直す
    def submitted_quantities(key)
      GhostForms::Quantities.from(submitted[key])
    end

    # 母集合は「元の販売の商品 + 当日の在庫」で、画面が数量入力を描画する範囲そのもの。
    # 未送信の初回描画では初期値がそのまま現在値なので、同じハッシュを共有する
    def build_corrected_quantities
      return original_corrected_quantities if submitted.absent?

      GhostForms::Quantities.dense(catalog_lookup.keys, submitted_quantities("corrected"))
    end

    # 母集合は available_discounts。有効期限切れなどで描画されないクーポンは枚数入力が
    # 出ず送信されようがないので、母集合に入れてはいけない。入れると「届かない」を
    # 「0枚に減った」と読んでしまう
    def build_coupon_quantities
      return original_coupon_quantities if submitted.absent?

      GhostForms::Quantities.dense(submittable_discount_ids, submitted_quantities("coupon"))
    end

    def submittable_discount_ids
      available_discounts.map(&:id)
    end

    def original_corrected_quantities
      @original_corrected_quantities ||= GhostForms::Quantities.dense(catalog_lookup.keys, original_item_quantities)
    end

    def original_coupon_quantities
      @original_coupon_quantities ||= GhostForms::Quantities.dense(submittable_discount_ids, original_discount_quantities)
    end

    def original_item_quantities
      @original_item_quantities ||= sale.items.group_by(&:catalog_id)
        .transform_values { |items| items.sum(&:quantity) }
    end

    # pluck はロード済みでも必ず問い合わせるので使わない。同じ関連を Preview も読む
    def original_discount_quantities
      @original_discount_quantities ||= sale.sale_discounts.to_h { |sd| [ sd.discount_id, sd.quantity ] }
    end

    # corrected が 1 件も届かないのは「全て 0」ではなく壊れた送信。全て 0 の確定は
    # 数量を 0 として明示的に送ってくる。ここを通すと corrected_items_for_refunder が
    # 空になり、修正後の販売が作られないまま元の販売が取り消されて全額返金になる。
    # corrected_quantities は母集合の分だけ必ず埋まる（ルール 7）ので空では見分けられず、
    # Submission が見る密化前のハッシュで判定する
    def required_submitted_keys
      %w[corrected]
    end

    # 読めない送信では「変更されたか」を判定しようがない
    def at_least_one_change
      return if submitted_unreadable?

      errors.add(:base, :no_items_selected) unless has_any_changes?
    end

    # 数量入力の母集合。corrected_quantities も corrected_items もここから派生するので、
    # 陳列できるかの検査もここに置く（描画を経ない確定経路にも同じ網が掛かる）
    def catalog_lookup
      @catalog_lookup ||= begin
        lookup = {}
        sale.items.each { |item| lookup[item.catalog_id] ||= item.catalog }
        inventories.each { |inv| lookup[inv.catalog_id] ||= inv.catalog }
        verify_displayable(lookup)
      end
    end

    def find_catalog(catalog_id)
      catalog_lookup[catalog_id]
    end

    def inventory_lookup
      @inventory_lookup ||= inventories.index_by(&:catalog_id)
    end

    def build_corrected_items
      catalog_lookup.filter_map do |catalog_id, catalog|
        next unless catalog

        quantity = corrected_quantities[catalog_id]
        original_qty = original_corrected_quantities[catalog_id]
        inventory = inventory_lookup[catalog_id]
        available_stock = inventory&.available_stock || 0
        # 在庫上限 = 元の数量 + 利用可能在庫（返品分の在庫は復元されるため）
        max_quantity = original_qty + available_stock

        CorrectedItem.new(
          catalog: catalog,
          quantity: quantity,
          original_quantity: original_qty,
          max_quantity: max_quantity,
          inventory: inventory
        )
      end
    end

    # Catalog#category に陳列カテゴリ以外の値が入ると、差額精算の画面はその商品の数量入力を
    # 描画しない。すると送信ボディにキーが現れず、元の販売側から拾われて「0 個に減った」と
    # 読まれ、ユーザーが何も触っていない商品が黙って返金される。カテゴリを名指しする他の箇所は
    # いずれも目に見えて壊れるので（一覧は ADR-0005）、黙って壊れるのはここだけである。
    #
    # 判定に Catalog::DISPLAY_CATEGORIES を使ってはいけない。あの定数は category_order が
    # 読むもので、3 つ目の区分を足す人は enum の隣のテストに促されて真っ先にあれを更新する。
    # ここが同じ定数を読むと、その瞬間にガードも一緒に外れ、tab_items を直す前に素通りする。
    # bento? / side_menu? は、下の bento_corrected_items / side_menu_corrected_items と
    # new_page の tab_items が実際に使っている述語そのもので、タブを増やすまで真にならない
    def verify_displayable(lookup)
      undisplayable = lookup.values.compact.reject { |catalog| catalog.bento? || catalog.side_menu? }
      return lookup if undisplayable.empty?

      names = undisplayable.map { |catalog| "#{catalog.name}(#{catalog.category.inspect})" }
      raise UndisplayableCategoryError, "陳列カテゴリに載らない商品が修正カートにあります: #{names.join(", ")}"
    end
  end
end
