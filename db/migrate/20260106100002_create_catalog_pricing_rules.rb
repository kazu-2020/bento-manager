class CreateCatalogPricingRules < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_pricing_rules, comment: "価格ルール（セット価格適用条件など）" do |t|
      t.references :target_catalog, null: false, foreign_key: { to_table: :catalogs }, comment: "適用対象商品ID"
      t.integer :price_kind, null: false, comment: "適用価格種別（0: regular, 1: bundle）"
      t.string :trigger_category, null: false, comment: "トリガーカテゴリ（bento/side_menu）"
      t.integer :max_per_trigger, null: false, default: 1, comment: "トリガー1つあたりの最大適用数"
      t.date :valid_from, null: false, comment: "ルール有効開始日"
      t.date :valid_until, comment: "ルール有効終了日（null=無期限）"
      t.timestamps
    end

    add_index :catalog_pricing_rules, :target_catalog_id, name: "idx_catalog_pricing_rules_target"
    add_index :catalog_pricing_rules, :trigger_category
    add_index :catalog_pricing_rules, :valid_from
  end
end
