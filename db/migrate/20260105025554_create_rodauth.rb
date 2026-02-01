class CreateRodauth < ActiveRecord::Migration[8.1]
  def change
    # Admins table for Rails console-managed admin accounts
    # Status: 1=unverified (unused), 2=verified (active), 3=closed (deactivated)
    # Username: Unique constraint only for active accounts (status IN (1,2)),
    #           allowing username reuse after account closure
    create_table :admins do |t|
      # Default status is 1 (unverified), but admins are created directly as verified via console
      t.integer :status, null: false, default: 1
      t.string :username, null: false, collation: "NOCASE", comment: "アカウント名（英数字とアンダースコアのみ、大文字小文字区別なし）"
      # Partial unique index: allows duplicate usernames for closed accounts (status=3)
      t.index :username, unique: true, where: "status IN (1, 2)"
      # bcrypt password hash
      t.string :password_hash
      t.timestamps
    end

    # Note: Username-based authentication tables (verification_keys, password_reset_keys,
    # login_change_keys) are not created as admins are managed via Rails console
  end
end
