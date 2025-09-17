class AddIndexToPlaysOnKexpPlayId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS index_plays_on_kexp_play_id
      ON plays (kexp_play_id)
      WHERE kexp_play_id IS NOT NULL;
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_plays_on_kexp_play_id;
    SQL
  end
end
