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

ActiveRecord::Schema[7.1].define(version: 2025_10_06_114239) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "backfill_statuses", force: :cascade do |t|
    t.integer "days"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "imported_count"
    t.string "status"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "plays", force: :cascade do |t|
    t.string "song"
    t.string "artist"
    t.string "album"
    t.string "play_type"
    t.datetime "played_at"
    t.integer "kexp_play_id"
    t.string "thumbnail_uri"
    t.string "show_uri"
    t.string "program_name"
    t.text "host_names"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "show_id"
    t.index ["kexp_play_id"], name: "index_plays_on_kexp_play_id", unique: true
    t.index ["show_id", "played_at", "artist", "song"], name: "index_plays_on_show_time_artist_song", unique: true, where: "((artist IS NOT NULL) AND (song IS NOT NULL))"
    t.index ["show_id"], name: "index_plays_on_show_id"
  end

  create_table "shows", force: :cascade do |t|
    t.integer "kexp_show_id"
    t.string "uri"
    t.string "program_name"
    t.text "host_names"
    t.datetime "airdate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "plays", "shows"
end
