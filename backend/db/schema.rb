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

ActiveRecord::Schema[8.1].define(version: 2025_10_27_190441) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "link_fetch_state", ["pending", "success", "failed"]

  create_table "link_tags", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "link_id", null: false
    t.uuid "tag_id", null: false
    t.index ["link_id", "tag_id"], name: "index_link_tags_on_link_id_and_tag_id", unique: true
    t.index ["link_id"], name: "index_link_tags_on_link_id"
    t.index ["tag_id"], name: "index_link_tags_on_tag_id"
  end

  create_table "links", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "content_text"
    t.datetime "created_at", null: false
    t.text "fetch_error"
    t.enum "fetch_state", default: "pending", null: false, enum_type: "link_fetch_state"
    t.datetime "fetched_at"
    t.string "image_url", limit: 2048
    t.jsonb "metadata", default: {}
    t.text "note"
    t.text "raw_html"
    t.string "submitted_url", limit: 2048, null: false
    t.string "title", limit: 500
    t.datetime "updated_at", null: false
    t.string "url", limit: 2048, null: false
    t.index ["created_at"], name: "index_links_on_created_at"
    t.index ["fetch_state"], name: "index_links_on_fetch_state"
    t.index ["metadata"], name: "index_links_on_metadata", using: :gin
    t.index ["url"], name: "index_links_on_url", unique: true
  end

  create_table "tags", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "last_used_at"
    t.string "name", limit: 100, null: false
    t.string "slug", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.index ["name"], name: "index_tags_on_name"
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  add_foreign_key "link_tags", "links"
  add_foreign_key "link_tags", "tags"
end
