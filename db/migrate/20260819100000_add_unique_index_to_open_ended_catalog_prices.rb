class AddUniqueIndexToOpenEndedCatalogPrices < ActiveRecord::Migration[8.1]
  # 終了していない価格は商品・種別ごとに 1 件だけ、という不変条件を DB に持たせる。
  # 2 件並ぶと price_by_kind の勝者が effective_from の同着次第で id 任せになり、
  # どちらが現在価格なのかがアプリ層の走査順に左右される。
  #
  # 部分インデックスなので終了済みの価格は対象外。値上げのたびに積み上がる履歴は
  # 同じ商品・種別で何件でも残せる。
  #
  # 同じ列の非ユニークな idx_catalog_prices_catalog_kind は残す。effective_at は
  # (effective_until IS NULL OR effective_until >= ?) という選言を出すため、この部分
  # インデックスの述語を含意せず、価格の検索には使われない。冗長判定して消してはいけない。
  #
  # テーブルの作り直しを伴わないため disable_ddl_transaction! は不要。
  def change
    add_index :catalog_prices, [ :catalog_id, :kind ],
              unique: true,
              where: "effective_until IS NULL",
              name: "idx_catalog_prices_open_ended_unique"
  end
end
