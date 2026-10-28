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

ActiveRecord::Schema[8.1].define(version: 2026_10_28_182047) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "email_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "purpose", limit: 30, null: false
    t.string "token_hash", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_hash"], name: "index_email_tokens_on_token_hash", unique: true
    t.index ["user_id"], name: "index_email_tokens_on_user_id"
    t.check_constraint "purpose::text = ANY (ARRAY['confirmation'::character varying, 'reset'::character varying]::text[])", name: "chk_email_tokens_purpose"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_hash", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_hash"], name: "index_refresh_tokens_on_token_hash", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.string "first_name", limit: 100, null: false
    t.string "last_name", limit: 100, null: false
    t.string "phone", limit: 32
    t.date "birth_date"
    t.string "avatar_url"
    t.string "city", limit: 100
    t.string "preferred_locale", limit: 2, default: "uk", null: false
    t.datetime "email_confirmed_at"
    t.virtual "is_email_confirmed", type: :boolean, null: false, as: "(email_confirmed_at IS NOT NULL)", stored: true
    t.boolean "is_active", default: true, null: false
    t.datetime "blocked_at"
    t.bigint "blocked_by_id"
    t.text "block_reason"
    t.string "platform_role", limit: 20, default: "user", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked_by_id"], name: "index_users_on_blocked_by_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "platform_role::text = ANY (ARRAY['user'::character varying, 'moderator'::character varying]::text[])", name: "chk_users_platform_role"
    t.check_constraint "preferred_locale::text = ANY (ARRAY['uk'::character varying, 'en'::character varying]::text[])", name: "chk_users_preferred_locale"
  end

  add_foreign_key "email_tokens", "users", on_delete: :cascade
  add_foreign_key "refresh_tokens", "users", on_delete: :cascade
  add_foreign_key "users", "users", column: "blocked_by_id", on_delete: :nullify
end
