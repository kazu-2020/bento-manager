class Employee < ActiveRecord::Migration[8.1]
  def change
    # Used by the lockout feature for employee accounts
    # Tracks failed login attempts to prevent brute-force attacks
    create_table :employee_login_failures, id: false do |t|
      t.integer :id, primary_key: true
      t.foreign_key :employees, column: :id
      t.integer :number, null: false, default: 1
    end

    # Stores account lockout information
    create_table :employee_lockouts, id: false do |t|
      t.integer :id, primary_key: true
      t.foreign_key :employees, column: :id
      t.string :key, null: false
      t.datetime :deadline, null: false
      t.datetime :email_last_sent
    end
  end
end
