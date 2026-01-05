# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_05_110543) do
  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_hash"
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true, where: "status IN (1, 2)"
  end

  create_table "employee_lockouts", force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent"
    t.string "key", null: false
  end

  create_table "employee_login_failures", force: :cascade do |t|
    t.integer "number", default: 1, null: false
  end

  create_table "employees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_hash"
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_employees_on_email", unique: true, where: "status IN (1, 2)"
  end

  add_foreign_key "employee_lockouts", "employees", column: "id"
  add_foreign_key "employee_login_failures", "employees", column: "id"
end
