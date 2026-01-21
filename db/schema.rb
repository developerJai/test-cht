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

ActiveRecord::Schema[7.1].define(version: 2026_01_21_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.string "image"
    t.text "reply_for"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "recipient_id"
    t.datetime "seen_by_admin_at"
    t.index ["recipient_id", "seen_by_admin_at"], name: "index_messages_on_recipient_id_and_seen_by_admin_at"
    t.index ["recipient_id", "user_id"], name: "index_messages_on_recipient_id_and_user_id"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["seen_by_admin_at"], name: "index_messages_on_seen_by_admin_at"
    t.index ["user_id", "recipient_id"], name: "index_messages_on_user_id_and_recipient_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "removed_texts", force: :cascade do |t|
    t.text "content"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_removed_texts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "password_digest"
    t.datetime "last_updated_at"
    t.datetime "last_clear_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_admin", default: false
    t.string "name"
    t.boolean "enabled", default: true
    t.json "conversation_activities", default: {}
    t.index ["enabled"], name: "index_users_on_enabled"
  end

  add_foreign_key "messages", "users"
  add_foreign_key "messages", "users", column: "recipient_id"
  add_foreign_key "removed_texts", "users"
end
