class AddKanaToCatalogs < ActiveRecord::Migration[8.1]
  def change
    add_column :catalogs, :kana, :string, null: false, default: "",
      comment: "商品名のふりがな（カタカナ）"
    add_index :catalogs, :kana
  end
end
