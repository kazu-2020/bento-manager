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

ActiveRecord::Schema[8.1].define(version: 2026_01_07_100437) do
  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_hash"
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true, where: "status IN (1, 2)"
  end

  create_table "catalog_discontinuations", force: :cascade do |t|
    t.integer "catalog_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discontinued_at", null: false
    t.text "reason", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_id"], name: "index_catalog_discontinuations_on_catalog_id", unique: true
  end

  create_table "catalog_prices", force: :cascade do |t|
    t.integer "catalog_id", null: false
    t.datetime "created_at", null: false
    t.datetime "effective_from", null: false
    t.datetime "effective_until"
    t.integer "kind", null: false
    t.integer "price", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_id", "kind"], name: "idx_catalog_prices_catalog_kind"
    t.index ["catalog_id"], name: "index_catalog_prices_on_catalog_id"
    t.index ["effective_from"], name: "index_catalog_prices_on_effective_from"
  end

  create_table "catalog_pricing_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "max_per_trigger", default: 1, null: false
    t.integer "price_kind", null: false
    t.integer "target_catalog_id", null: false
    t.integer "trigger_category", null: false
    t.datetime "updated_at", null: false
    t.date "valid_from", null: false
    t.date "valid_until"
    t.index ["target_catalog_id"], name: "index_catalog_pricing_rules_on_target_catalog_id"
    t.index ["trigger_category"], name: "index_catalog_pricing_rules_on_trigger_category"
    t.index ["valid_from"], name: "index_catalog_pricing_rules_on_valid_from"
  end

  create_table "catalogs", force: :cascade do |t|
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_catalogs_on_category"
    t.index ["name"], name: "idx_catalogs_name", unique: true
  end

  create_table "coupons", force: :cascade do |t|
    t.integer "amount_per_unit", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "max_per_bento_quantity", null: false
    t.datetime "updated_at", null: false
  end

  create_table "discounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "discountable_id", null: false
    t.string "discountable_type", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.date "valid_from", null: false
    t.date "valid_until"
    t.index ["discountable_type", "discountable_id"], name: "idx_discounts_discountable", unique: true
    t.index ["name"], name: "idx_discounts_name"
    t.index ["valid_from", "valid_until"], name: "idx_discounts_validity"
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

  create_table "locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "idx_locations_name", unique: true
    t.index ["status"], name: "index_locations_on_status"
  end

  add_foreign_key "catalog_discontinuations", "catalogs", on_delete: :restrict
  add_foreign_key "catalog_prices", "catalogs", on_delete: :restrict
  add_foreign_key "catalog_pricing_rules", "catalogs", column: "target_catalog_id", on_delete: :restrict
  add_foreign_key "employee_lockouts", "employees", column: "id"
  add_foreign_key "employee_login_failures", "employees", column: "id"
end
