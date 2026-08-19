require "test_helper"

class CatalogPriceTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_prices

  test "validations" do
    @subject = CatalogPrice.new(
      catalog: catalogs(:daily_bento_a),
      kind: :regular,
      price: 500,
      effective_from: Time.current
    )

    must validate_presence_of(:kind)
    must validate_presence_of(:price)
    must validate_numericality_of(:price).is_greater_than(0)
    must validate_presence_of(:effective_from)
    must define_enum_for(:kind).with_values(regular: 0, bundle: 1).validating
  end

  test "associations" do
    @subject = CatalogPrice.new

    must belong_to(:catalog)
    must have_many(:sale_items).dependent(:restrict_with_error)
  end

  test "有効期限の終了日時は開始日時より後でなければならない" do
    catalog = catalogs(:daily_bento_a)
    now = Time.current

    before_start = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: now, effective_until: 1.day.ago)

    assert_not before_start.valid?
    assert_includes before_start.errors[:effective_until], "は適用開始日時より後の日時を指定してください"

    same_time = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: now, effective_until: now)

    assert_not same_time.valid?

    after_start = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: now, effective_until: 1.day.from_now)

    assert_predicate after_start, :valid?

    no_end = CatalogPrice.new(catalog: catalog, kind: :regular, price: 500, effective_from: now, effective_until: nil)

    assert_predicate no_end, :valid?
  end

  test "有効期間内の価格のみが取得される" do
    catalog = catalogs(:discontinued_bento)

    past_price = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 400, effective_from: 2.days.ago, effective_until: 1.day.ago)
    current_price = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 500, effective_from: 1.day.ago, effective_until: nil)
    # 終了時刻を入れるのは未来の価格のほう。現在の価格を終了させると
    # 「終了なし＝現在有効」という effective_at の分岐が含まれる側で検証されなくなる
    future_price = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 600, effective_from: 1.day.from_now, effective_until: 2.days.from_now)

    result = CatalogPrice.current

    assert_includes result, current_price
    assert_not_includes result, past_price
    assert_not_includes result, future_price
  end

  test "指定した種別と日時の有効な価格を取得できる" do
    catalog = catalogs(:miso_soup)

    past_price = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 500, effective_from: 1.week.ago, effective_until: 1.day.ago)
    current_regular = CatalogPrice.create!(catalog: catalog, kind: :regular, price: 600, effective_from: 1.day.ago, effective_until: nil)
    current_bundle = CatalogPrice.create!(catalog: catalog, kind: :bundle, price: 500, effective_from: 1.day.ago, effective_until: nil)

    assert_equal current_regular, catalog.prices.price_by_kind(kind: :regular)
    assert_equal current_bundle, catalog.prices.price_by_kind(kind: :bundle)
    assert_equal past_price, catalog.prices.price_by_kind(kind: :regular, at: 3.days.ago)

    empty_catalog = catalogs(:discontinued_bento)

    assert_nil empty_catalog.prices.price_by_kind(kind: :regular)
  end

  test "適用開始日時が未設定の価格は、どの時点でも有効ではない" do
    assert_not CatalogPrice.new(kind: :regular, price: 500).effective_at?(Time.current)
    assert_not CatalogPrice.new(kind: :regular, price: 500).effective_at?(Date.current)
  end

  test "新しい価格を設定すると既存の価格が終了する" do
    catalog = catalogs(:daily_bento_a)
    old_price = catalog_prices(:daily_bento_a_regular)

    assert_nil old_price.effective_until

    new_price = CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 600)

    assert_predicate new_price, :persisted?
    assert_equal 600, new_price.price
    assert_nil new_price.effective_until

    old_price.reload
    switched_at = new_price.reload.effective_from

    # Time.current を 2 度評価すると旧価格の終了が新価格の開始より後ろにずれ、
    # その差分がどちらも有効な期間になる。保存で丸めた値どうしで突き合わせる
    assert_equal switched_at, old_price.effective_until

    # ただし effective_at は両端 inclusive なので、切替の一点では依然 2 件とも有効。
    # 重複が消えたのではなく 1 点に縮んだだけで、勝者は effective_from の降順が決める
    assert_equal 2, catalog.prices.by_kind(:regular).effective_at(switched_at).count
    assert_equal new_price, catalog.prices.price_by_kind(kind: :regular, at: switched_at)
  end

  test "同じ時刻に価格を続けて変えても履歴は積まれず金額だけ変わる" do
    catalog = catalogs(:daily_bento_a)

    # freeze_time 下では旧価格の effective_from と新価格の effective_from が同値になる。
    # 終了時刻を入れると valid_date_range に掛かるので、行を積まずに上書きする
    freeze_time do
      first = CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 600)

      assert_no_difference "CatalogPrice.count" do
        second = CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 650)

        assert_equal first.id, second.id
      end

      assert_equal 650, catalog.reload.price_by_kind(:regular).price
      assert_equal 1, catalog.prices.open_ended.by_kind(:regular).count
    end
  end

  test "まだ始まっていない価格しか無いときは、その価格を今から有効にする" do
    catalog = catalogs(:miso_soup)
    CatalogPrice.create!(
      catalog: catalog, kind: :regular, price: 700, effective_from: 1.week.from_now
    )

    CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 800)

    # 開始時刻を未来に据え置くと、呼び出した直後なのにどの価格も現在有効でなくなる
    assert_equal 800, catalog.reload.price_by_kind(:regular)&.price
    assert_equal 1, catalog.prices.open_ended.by_kind(:regular).count
  end

  test "終了時刻が未来の価格が挟まっていても、終了していない価格を閉じられる" do
    catalog = catalogs(:daily_bento_a)
    open_ended = catalog_prices(:daily_bento_a_regular)

    # 現在有効な価格（effective_at の勝者）と終了していない価格がずれる形。
    # 閉じる相手を effective_at で選ぶと、この行が閉じられず一意制約に弾かれる
    CatalogPrice.create!(
      catalog: catalog, kind: :regular, price: 700,
      effective_from: 1.day.ago, effective_until: 1.month.from_now
    )

    new_price = CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 800)

    assert_not_nil open_ended.reload.effective_until
    assert_equal 1, catalog.prices.open_ended.by_kind(:regular).count
    assert_equal new_price, catalog.prices.open_ended.by_kind(:regular).first
  end

  test "価格設定が不正な場合は既存の価格も変更されない" do
    catalog = catalogs(:daily_bento_a)
    old_price = catalog_prices(:daily_bento_a_regular)

    assert_raises(ActiveRecord::RecordInvalid) do
      CatalogPrice.create_with_history!(catalog: catalog, kind: :regular, price: 0)
    end

    old_price.reload

    assert_nil old_price.effective_until
  end
end
