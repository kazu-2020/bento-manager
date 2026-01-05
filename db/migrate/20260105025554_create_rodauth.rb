class CreateRodauth < ActiveRecord::Migration[8.1]
  def change
    # Admins table for Rails console-managed admin accounts
    # Status: 1=unverified (unused), 2=verified (active), 3=closed (deactivated)
    # Email: Unique constraint only for active accounts (status IN (1,2)),
    #        allowing email reuse after account closure
    create_table :admins do |t|
      # Default status is 1 (unverified), but admins are created directly as verified via console
      t.integer :status, null: false, default: 1
      t.string :email, null: false
      # Partial unique index: allows duplicate emails for closed accounts (status=3)
      t.index :email, unique: true, where: "status IN (1, 2)"
      # bcrypt password hash
      t.string :password_hash
      # Admin display name
      t.string :name, null: false
      t.timestamps
    end

    # Note: Email-based authentication tables (verification_keys, password_reset_keys,
    # login_change_keys) are not created as admins are managed via Rails console
  end
end
