# app/models/play.rb
class Play < ApplicationRecord
  belongs_to :show, optional: true

  validates :kexp_play_id, presence: true, uniqueness: true
  validates :played_at,    presence: true

  scope :for_program, ->(program_name) {
    joins(:show)
      .where(shows: { program_name: program_name })
      .where.not(artist: nil, song: nil)
  }

  scope :within_show_window, -> {
    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
    condition =
      if adapter.include?("sqlite")
        # 10 minutes before start, 10 minutes after end
        "plays.played_at >= datetime(shows.airdate, '-10 minutes') AND plays.played_at < datetime(shows.airdate, '+3 hours', '+10 minutes')"
      else
        "plays.played_at >= (shows.airdate - INTERVAL '10 minutes') AND plays.played_at < (shows.airdate + INTERVAL '3 hours 10 minutes')"
      end
    joins(:show).where(condition)
  }

  def self.top_songs_for(program_name, since: nil, limit: 40)
    # Use all Morning Show plays (don’t restrict to 3h window)
    rel = for_program(program_name)
    rel = rel.where("plays.played_at >= ?", since) if since.present?

    rel.group(:artist, :song)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(limit)
      .count
      .map { |(artist, song), count| [artist, song, count] }
  end

  # ------------------------------------------------------------
  # Normalized top songs (Postgres preferred)
  # - Collapses things like "feat." variants for artist
  # - Strips non-alphanumeric from song for grouping
  # Returns: [[artist, song, count], ...]
  # If not Postgres, falls back to simple grouping.
  # ------------------------------------------------------------
  def self.top_songs_for(program_name, since: nil, limit: 40)
    rel = for_program(program_name)
    rel = rel.where("plays.played_at >= ?", since) if since.present?

    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase

    if adapter.include?("postgres")
      # Postgres: normalize artist (drop " feat. ..."), normalize song (alnum only), lower-case
      rel = rel
        .select(
          "LOWER(REGEXP_REPLACE(plays.artist, '\\s+feat\\..*$', '')) AS akey",
          "LOWER(REGEXP_REPLACE(plays.song,   '[^a-z0-9]+', '', 'g')) AS skey",
          "MIN(plays.artist) AS sample_artist",
          "MIN(plays.song)   AS sample_song",
          "COUNT(*)          AS cnt"
        )
        .group("akey, skey")
        .order(Arel.sql("cnt DESC"))
        .limit(limit)
    else
      # SQLite / others: simpler normalization
      rel = rel
        .select(
          "LOWER(plays.artist) AS akey",
          "LOWER(plays.song)   AS skey",
          "MIN(plays.artist)   AS sample_artist",
          "MIN(plays.song)     AS sample_song",
          "COUNT(*)            AS cnt"
        )
        .group("akey, skey")
        .order(Arel.sql("cnt DESC"))
        .limit(limit)
    end

    # Return [[artist, song, count], ...]
    rel.map { |r| [r["sample_artist"], r["sample_song"], r["cnt"].to_i] }
  end
end

# pp Play.top_songs_normalized("The Morning Show", since: 3.months.ago, limit: 20)
