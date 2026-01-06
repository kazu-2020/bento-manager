class CreateCatalogDiscontinuations < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_discontinuations, comment: "商品提供終了記録" do |t|
      t.references :catalog, null: false, foreign_key: { on_delete: :restrict }, index: { unique: true }, comment: "商品ID（ユニーク）"
      t.datetime :discontinued_at, null: false, comment: "提供終了日時"
      t.text :reason, null: false, comment: "提供終了理由"
      t.timestamps
    end
  end
end
