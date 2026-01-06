class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations, comment: "販売先マスタ" do |t|
      t.string :name, null: false, comment: "販売先名称（例: 市役所、県庁）"
      t.integer :status, null: false, default: 0, comment: "販売状態（0: active, 1: inactive）"
      t.timestamps
    end

    add_index :locations, :name, unique: true, name: "idx_locations_name"
    add_index :locations, :status
  end
end
