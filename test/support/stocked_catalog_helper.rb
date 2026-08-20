# 当日在庫のある商品を扱うヘルパー
#
# 「カートの商品の種類が増えても問い合わせ本数が増えない」を測るテストは、販売・返品の
# どちらも同じ母集合（当日在庫）を増やして比べる。片方に置くと形が揃わないためここに置く
module StockedCatalogHelper
  # 当日在庫のある商品を 1 種類増やす
  #
  # 価格ルールを持たない商品でも、カートに入れば 1 種類につき 1 本引かれる。
  # 増やすのは regular 価格だけの素朴な商品で足りる
  #
  # @param location [Location] 在庫を積む販売先
  # @return [Catalog] 増やした商品
  def stock_new_catalog(location)
    catalog = Catalog.create!(name: "追加サイド", kana: "ツイカサイド", category: :side_menu)
    CatalogPrice.create!(catalog: catalog, kind: :regular, price: 120, effective_from: 1.month.ago)
    DailyInventory.create!(
      location: location, catalog: catalog,
      inventory_date: Date.current, stock: 5, reserved_stock: 0
    )
    catalog
  end

  # 当日在庫のある商品すべて（＝カートの母集合）
  #
  # @param location [Location] 販売先
  # @return [ActiveRecord::Relation<Catalog>]
  def stocked_catalogs(location)
    Catalog.where(id: location.today_inventories.select(:catalog_id))
  end
end
