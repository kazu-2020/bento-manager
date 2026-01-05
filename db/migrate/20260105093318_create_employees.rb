class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    # Employees table for business users (owner and salesperson)
    # Status: 1=unverified (unused), 2=verified (active), 3=closed (deactivated)
    # Email: Unique constraint only for active accounts (status IN (1,2)),
    #        allowing email reuse after account closure
    create_table :employees do |t|
      # Default status is 1 (unverified). When Admin creates an employee,
      # the status should be explicitly set to 2 (verified) during creation.
      t.integer :status, null: false, default: 1
      t.string :email, null: false
      # Partial unique index: allows duplicate emails for closed accounts (status=3)
      t.index :email, unique: true, where: "status IN (1, 2)"
      # bcrypt password hash
      t.string :password_hash
      # Employee display name
      t.string :name, null: false
      t.timestamps
    end
  end
end
