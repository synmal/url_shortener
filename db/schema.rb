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

ActiveRecord::Schema[8.1].define(version: 2026_04_25_080715) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "short_urls", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "slug", null: false
    t.bigint "target_url_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "visits_count", default: 0, null: false
    t.index ["slug"], name: "index_short_urls_on_slug", unique: true
    t.index ["target_url_id"], name: "index_short_urls_on_target_url_id"
    t.index ["user_id"], name: "index_short_urls_on_user_id"
  end

  create_table "target_urls", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "visits", force: :cascade do |t|
    t.string "country"
    t.datetime "created_at", null: false
    t.string "ip_address", null: false
    t.float "latitude"
    t.float "longitude"
    t.datetime "processed_at"
    t.bigint "short_url_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "visited_at", null: false
    t.index ["processed_at"], name: "index_visits_on_processed_at", where: "(processed_at IS NULL)"
    t.index ["short_url_id"], name: "index_visits_on_short_url_id"
  end

  add_foreign_key "short_urls", "target_urls"
  add_foreign_key "short_urls", "users"
  add_foreign_key "visits", "short_urls"
end
