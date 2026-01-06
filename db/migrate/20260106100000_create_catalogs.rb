class CreateCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :catalogs, comment: "商品カタログマスタ" do |t|
      t.string :name, null: false, comment: "商品名（例: 日替わり弁当A、サラダ）"
      t.integer :category, null: false, comment: "商品カテゴリ（0: bento, 1: side_menu）"
      t.text :description, null: false, default: "", comment: "商品説明"
      t.timestamps
    end

    add_index :catalogs, :name, unique: true, name: "idx_catalogs_name"
    add_index :catalogs, :category
  end
end
