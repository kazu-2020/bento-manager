class CreateCatalogPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_prices, comment: "商品価格（種別別: regular/bundle）" do |t|
      t.references :catalog, null: false, foreign_key: true, comment: "商品ID"
      t.integer :kind, null: false, comment: "価格種別（0: regular, 1: bundle）"
      t.integer :price, null: false, comment: "価格（税込）"
      t.datetime :effective_from, null: false, comment: "価格適用開始日時"
      t.datetime :effective_until, comment: "価格適用終了日時（null=無期限）"
      t.timestamps
    end

    add_index :catalog_prices, [:catalog_id, :kind], name: "idx_catalog_prices_catalog_kind"
    add_index :catalog_prices, :effective_from
  end
end
