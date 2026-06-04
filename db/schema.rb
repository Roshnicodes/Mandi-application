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

ActiveRecord::Schema[8.1].define(version: 2026_05_23_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "arrival_units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "short_name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_arrival_units_on_name", unique: true
  end

  create_table "candy_rates", force: :cascade do |t|
    t.string "category", null: false
    t.bigint "cotton_bulletin_id", null: false
    t.datetime "created_at", null: false
    t.string "madhya_pradesh_rate"
    t.string "maharashtra_29mm_rate"
    t.string "maharashtra_31mm_rate"
    t.string "odisha_29mm_rate"
    t.string "odisha_30mm_rate"
    t.string "parameter", null: false
    t.integer "position"
    t.string "reference"
    t.datetime "updated_at", null: false
    t.index ["cotton_bulletin_id", "category"], name: "index_candy_rates_on_bulletin_and_category"
    t.index ["cotton_bulletin_id"], name: "index_candy_rates_on_cotton_bulletin_id"
  end

  create_table "commodities", force: :cascade do |t|
    t.bigint "commodity_group_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "organic", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["commodity_group_id", "name"], name: "index_commodities_on_commodity_group_id_and_name", unique: true
    t.index ["commodity_group_id"], name: "index_commodities_on_commodity_group_id"
  end

  create_table "commodity_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_commodity_groups_on_name", unique: true
  end

  create_table "cotton_bulletins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "notes"
    t.date "report_date", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["report_date", "title"], name: "index_cotton_bulletins_on_report_date_and_title"
  end

  create_table "cotton_call_performances", force: :cascade do |t|
    t.integer "call_again", default: 0, null: false
    t.bigint "cotton_bulletin_id", null: false
    t.datetime "created_at", null: false
    t.integer "fully_satisfied", default: 0, null: false
    t.integer "invalid_exist", default: 0, null: false
    t.integer "position"
    t.decimal "satisfaction_percent", precision: 8, scale: 2
    t.integer "total_calls", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "wrong_call", default: 0, null: false
    t.index ["cotton_bulletin_id"], name: "index_cotton_call_performances_on_cotton_bulletin_id"
  end

  create_table "cotton_market_observations", force: :cascade do |t|
    t.string "arrival_price"
    t.decimal "arrival_quantity", precision: 12, scale: 2
    t.decimal "buy_percentage", precision: 8, scale: 2
    t.string "category", null: false
    t.decimal "cci_buy", precision: 12, scale: 2
    t.decimal "cci_percentage", precision: 8, scale: 2
    t.bigint "cotton_bulletin_id", null: false
    t.datetime "created_at", null: false
    t.decimal "maximum_price", precision: 12, scale: 2
    t.decimal "minimum_price", precision: 12, scale: 2
    t.decimal "modal_price", precision: 12, scale: 2
    t.string "moisture"
    t.string "name"
    t.date "observation_date"
    t.integer "position"
    t.text "remarks"
    t.decimal "total_arrival", precision: 12, scale: 2
    t.decimal "traders_buy", precision: 12, scale: 2
    t.decimal "traders_percentage", precision: 8, scale: 2
    t.datetime "updated_at", null: false
    t.index ["cotton_bulletin_id", "category"], name: "index_cotton_observations_on_bulletin_and_category"
    t.index ["cotton_bulletin_id"], name: "index_cotton_market_observations_on_cotton_bulletin_id"
    t.index ["observation_date"], name: "index_cotton_market_observations_on_observation_date"
  end

  create_table "cotton_regional_comparisons", force: :cascade do |t|
    t.bigint "cotton_bulletin_id", null: false
    t.datetime "created_at", null: false
    t.string "extra_value_one"
    t.string "extra_value_two"
    t.string "jobat_value"
    t.string "kukshi_value"
    t.string "line_item", null: false
    t.string "odisha_value"
    t.string "ojhar_value"
    t.string "pati_value"
    t.integer "position"
    t.string "raipur_value"
    t.string "sausar_value"
    t.datetime "updated_at", null: false
    t.index ["cotton_bulletin_id"], name: "index_cotton_regional_comparisons_on_cotton_bulletin_id"
  end

  create_table "cotton_seed_rates", force: :cascade do |t|
    t.bigint "cotton_bulletin_id", null: false
    t.datetime "created_at", null: false
    t.string "madhya_pradesh_rate"
    t.string "maharashtra_rate"
    t.string "odisha_rate"
    t.string "particular", null: false
    t.integer "position"
    t.string "reference"
    t.datetime "updated_at", null: false
    t.index ["cotton_bulletin_id"], name: "index_cotton_seed_rates_on_cotton_bulletin_id"
  end

  create_table "daily_price_arrival_reports", force: :cascade do |t|
    t.date "arrival_date", null: false
    t.decimal "arrival_quantity", precision: 12, scale: 2, null: false
    t.bigint "arrival_unit_id", null: false
    t.bigint "commodity_group_id", null: false
    t.bigint "commodity_id", null: false
    t.datetime "created_at", null: false
    t.bigint "district_id", null: false
    t.bigint "grade_id", null: false
    t.bigint "market_id", null: false
    t.decimal "max_price", precision: 12, scale: 2, null: false
    t.decimal "min_price", precision: 12, scale: 2, null: false
    t.decimal "modal_price", precision: 12, scale: 2, null: false
    t.bigint "price_unit_id", null: false
    t.text "remarks"
    t.bigint "state_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "variety_id", null: false
    t.index ["arrival_date", "market_id", "commodity_id"], name: "index_reports_on_date_market_commodity"
    t.index ["arrival_unit_id"], name: "index_daily_price_arrival_reports_on_arrival_unit_id"
    t.index ["commodity_group_id"], name: "index_daily_price_arrival_reports_on_commodity_group_id"
    t.index ["commodity_id"], name: "index_daily_price_arrival_reports_on_commodity_id"
    t.index ["district_id"], name: "index_daily_price_arrival_reports_on_district_id"
    t.index ["grade_id"], name: "index_daily_price_arrival_reports_on_grade_id"
    t.index ["market_id"], name: "index_daily_price_arrival_reports_on_market_id"
    t.index ["price_unit_id"], name: "index_daily_price_arrival_reports_on_price_unit_id"
    t.index ["state_id"], name: "index_daily_price_arrival_reports_on_state_id"
    t.index ["variety_id"], name: "index_daily_price_arrival_reports_on_variety_id"
  end

  create_table "districts", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "state_id", null: false
    t.datetime "updated_at", null: false
    t.index ["state_id", "name"], name: "index_districts_on_state_id_and_name", unique: true
    t.index ["state_id"], name: "index_districts_on_state_id"
  end

  create_table "grades", force: :cascade do |t|
    t.bigint "commodity_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "variety_id"
    t.index ["commodity_id", "variety_id", "name"], name: "index_grades_on_commodity_id_and_variety_id_and_name", unique: true
    t.index ["commodity_id"], name: "index_grades_on_commodity_id"
    t.index ["variety_id"], name: "index_grades_on_variety_id"
  end

  create_table "markets", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.bigint "district_id", null: false
    t.string "market_type", default: "APMC", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["district_id", "name"], name: "index_markets_on_district_id_and_name", unique: true
    t.index ["district_id"], name: "index_markets_on_district_id"
  end

  create_table "price_units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "short_name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_price_units_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "states", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_states_on_code", unique: true
    t.index ["name"], name: "index_states_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "varieties", force: :cascade do |t|
    t.bigint "commodity_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["commodity_id", "name"], name: "index_varieties_on_commodity_id_and_name", unique: true
    t.index ["commodity_id"], name: "index_varieties_on_commodity_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "candy_rates", "cotton_bulletins"
  add_foreign_key "commodities", "commodity_groups"
  add_foreign_key "cotton_call_performances", "cotton_bulletins"
  add_foreign_key "cotton_market_observations", "cotton_bulletins"
  add_foreign_key "cotton_regional_comparisons", "cotton_bulletins"
  add_foreign_key "cotton_seed_rates", "cotton_bulletins"
  add_foreign_key "daily_price_arrival_reports", "arrival_units"
  add_foreign_key "daily_price_arrival_reports", "commodities"
  add_foreign_key "daily_price_arrival_reports", "commodity_groups"
  add_foreign_key "daily_price_arrival_reports", "districts"
  add_foreign_key "daily_price_arrival_reports", "grades"
  add_foreign_key "daily_price_arrival_reports", "markets"
  add_foreign_key "daily_price_arrival_reports", "price_units"
  add_foreign_key "daily_price_arrival_reports", "states"
  add_foreign_key "daily_price_arrival_reports", "varieties"
  add_foreign_key "districts", "states"
  add_foreign_key "grades", "commodities"
  add_foreign_key "grades", "varieties"
  add_foreign_key "markets", "districts"
  add_foreign_key "sessions", "users"
  add_foreign_key "varieties", "commodities"
end
