# frozen_string_literal: true

ActiveRecord::Schema[7.1].define(version: 2026_01_01_000000) do
  create_table "onetimer_tasks", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_onetimer_tasks_on_name", unique: true
  end
end
