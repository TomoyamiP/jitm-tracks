class CreateBackfillStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :backfill_statuses do |t|
      t.integer :days,           null: false
      t.string  :status,         null: false, default: "running"  # running | success | failed
      t.integer :imported_count, null: false, default: 0
      t.datetime :started_at,    null: false
      t.datetime :finished_at
      t.text    :error_message

      t.timestamps
    end

    add_index :backfill_statuses, :status
    add_index :backfill_statuses, :started_at
  end
end
