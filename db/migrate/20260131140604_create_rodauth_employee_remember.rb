class CreateRodauthEmployeeRemember < ActiveRecord::Migration[8.1]
  def change
    # Used by the remember me feature
    create_table :employee_remember_keys, id: false, comment: "従業員のRemember Me機能用トークン管理" do |t|
      t.integer :id, primary_key: true
      t.foreign_key :employees, column: :id
      t.string :key, null: false, comment: "ランダム生成されたRememberトークン"
      t.datetime :deadline, null: false, comment: "トークンの有効期限"
    end
  end
end
