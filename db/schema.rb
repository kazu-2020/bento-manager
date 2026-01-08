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

ActiveRecord::Schema[8.1].define(version: 2026_01_07_232222) do
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

  create_table "daily_inventories", force: :cascade do |t|
    t.integer "catalog_id", null: false
    t.datetime "created_at", null: false
    t.date "inventory_date", null: false
    t.integer "location_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "reserved_stock", default: 0, null: false
    t.integer "stock", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_id"], name: "index_daily_inventories_on_catalog_id"
    t.index ["location_id", "catalog_id", "inventory_date"], name: "idx_daily_inventories_location_catalog_date", unique: true
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

  create_table "sale_items", force: :cascade do |t|
    t.integer "catalog_id", null: false
    t.integer "catalog_price_id", null: false
    t.datetime "created_at", null: false
    t.integer "line_total", null: false
    t.integer "quantity", null: false
    t.integer "sale_id", null: false
    t.datetime "sold_at", null: false
    t.integer "unit_price", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_id"], name: "index_sale_items_on_catalog_id"
    t.index ["catalog_price_id"], name: "index_sale_items_on_catalog_price_id"
    t.index ["sale_id", "catalog_id"], name: "idx_sale_items_sale_catalog"
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
  end

  create_table "sales", force: :cascade do |t|
    t.bigint "corrected_from_sale_id"
    t.datetime "created_at", null: false
    t.integer "customer_type", null: false
    t.integer "employee_id"
    t.integer "final_amount", null: false
    t.integer "location_id", null: false
    t.datetime "sale_datetime", null: false
    t.integer "status", default: 0, null: false
    t.integer "total_amount", null: false
    t.datetime "updated_at", null: false
    t.string "void_reason"
    t.datetime "voided_at"
    t.bigint "voided_by_employee_id"
    t.index ["employee_id"], name: "index_sales_on_employee_id"
    t.index ["location_id", "sale_datetime"], name: "idx_sales_location_datetime"
    t.index ["location_id"], name: "index_sales_on_location_id"
    t.index ["sale_datetime"], name: "idx_sales_datetime"
    t.index ["status"], name: "idx_sales_status"
  end

  add_foreign_key "catalog_discontinuations", "catalogs", on_delete: :restrict
  add_foreign_key "catalog_prices", "catalogs", on_delete: :restrict
  add_foreign_key "catalog_pricing_rules", "catalogs", column: "target_catalog_id", on_delete: :restrict
  add_foreign_key "daily_inventories", "catalogs", on_delete: :restrict
  add_foreign_key "daily_inventories", "locations", on_delete: :restrict
  add_foreign_key "employee_lockouts", "employees", column: "id"
  add_foreign_key "employee_login_failures", "employees", column: "id"
  add_foreign_key "sale_items", "catalog_prices", on_delete: :restrict
  add_foreign_key "sale_items", "catalogs", on_delete: :restrict
  add_foreign_key "sale_items", "sales", on_delete: :cascade
  add_foreign_key "sales", "employees"
  add_foreign_key "sales", "employees", column: "voided_by_employee_id"
  add_foreign_key "sales", "locations"
  add_foreign_key "sales", "sales", column: "corrected_from_sale_id"
end
