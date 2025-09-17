# db/migrate/XXXXXXXXXXXX_add_unique_index_to_plays_on_show_time_artist_song.rb
class AddUniqueIndexToPlaysOnShowTimeArtistSong < ActiveRecord::Migration[7.1]
  # Needed for CREATE INDEX CONCURRENTLY on Postgres
  disable_ddl_transaction!

  def up
    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase

    if adapter.include?("postgres")
      execute <<~SQL
        CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS index_plays_on_show_time_artist_song
        ON plays (show_id, played_at, artist, song)
        WHERE artist IS NOT NULL AND song IS NOT NULL;
      SQL
    else
      # Fallback (SQLite/MySQL): create a plain unique index (no partial WHERE).
      # We already skip blanks in code, so this is acceptable.
      add_index :plays, [:show_id, :played_at, :artist, :song],
                unique: true,
                name: :index_plays_on_show_time_artist_song
    end
  end

  def down
    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase

    if adapter.include?("postgres")
      execute <<~SQL
        DROP INDEX CONCURRENTLY IF EXISTS index_plays_on_show_time_artist_song;
      SQL
    else
      remove_index :plays, name: :index_plays_on_show_time_artist_song
    end
  end
end
