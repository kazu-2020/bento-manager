require "test_helper"

class CatalogDiscontinuationTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_discontinuations

  # ===== バリデーションテスト =====

  test "catalog は必須" do
    discontinuation = CatalogDiscontinuation.new(
      catalog: nil,
      discontinued_at: Time.current,
      reason: "売上不振のため"
    )
    assert_not discontinuation.valid?
    assert_includes discontinuation.errors[:catalog], "を入力してください"
  end

  test "discontinued_at は必須" do
    catalog = catalogs(:discontinued_bento)
    discontinuation = CatalogDiscontinuation.new(
      catalog: catalog,
      discontinued_at: nil,
      reason: "売上不振のため"
    )
    assert_not discontinuation.valid?
    assert_includes discontinuation.errors[:discontinued_at], "を入力してください"
  end

  test "reason は必須" do
    catalog = catalogs(:discontinued_bento)
    discontinuation = CatalogDiscontinuation.new(
      catalog: catalog,
      discontinued_at: Time.current,
      reason: nil
    )
    assert_not discontinuation.valid?
    assert_includes discontinuation.errors[:reason], "を入力してください"
  end

  test "有効な属性で作成できる" do
    catalog = catalogs(:discontinued_bento)
    discontinuation = CatalogDiscontinuation.new(
      catalog: catalog,
      discontinued_at: Time.current,
      reason: "売上不振のため"
    )
    assert discontinuation.valid?, "有効な属性で CatalogDiscontinuation を作成できるべき: #{discontinuation.errors.full_messages.join(', ')}"
  end

  # ===== ユニーク制約テスト =====

  test "同じ catalog_id で複数の discontinuation は作成できない" do
    catalog = catalogs(:daily_bento_a)

    # 最初の提供終了記録を作成
    first_discontinuation = CatalogDiscontinuation.create!(
      catalog: catalog,
      discontinued_at: Time.current,
      reason: "最初の提供終了"
    )

    # 同じ catalog_id で2つ目を作成しようとするとエラー
    second_discontinuation = CatalogDiscontinuation.new(
      catalog: catalog,
      discontinued_at: Time.current,
      reason: "2回目の提供終了"
    )

    assert_not second_discontinuation.valid?
    assert_includes second_discontinuation.errors[:catalog_id], "はすでに存在します"
  end

  test "異なる catalog_id では複数の discontinuation を作成できる" do
    bento_a = catalogs(:daily_bento_a)
    bento_b = catalogs(:daily_bento_b)

    discontinuation_a = CatalogDiscontinuation.create!(
      catalog: bento_a,
      discontinued_at: Time.current,
      reason: "弁当A提供終了"
    )

    discontinuation_b = CatalogDiscontinuation.new(
      catalog: bento_b,
      discontinued_at: Time.current,
      reason: "弁当B提供終了"
    )

    assert discontinuation_b.valid?, "異なる catalog_id では作成できるべき"
  end

  # ===== アソシエーションテスト =====

  test "catalog との関連が正しく設定されている" do
    catalog = catalogs(:salad)
    discontinuation = CatalogDiscontinuation.create!(
      catalog: catalog,
      discontinued_at: Time.current,
      reason: "サラダ提供終了"
    )

    assert_equal catalog, discontinuation.catalog
  end
end
