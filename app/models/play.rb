# app/models/play.rb
class Play < ApplicationRecord
  belongs_to :show, optional: true

  validates :kexp_play_id, presence: true, uniqueness: true
  validates :played_at,    presence: true

  # Scope: all plays for a given program, ignoring blanks
  scope :for_program, ->(program_name) {
    joins(:show)
      .where(shows: { program_name: program_name })
      .where.not(artist: nil, song: nil)
  }

  # Scope: only plays that occurred during the show block (show.airdate .. +3 hours)
  # Uses different SQL for SQLite vs other adapters (Postgres), so it works locally and in prod.
  scope :within_show_window, -> {
    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
    condition =
      if adapter.include?("sqlite")
        "plays.played_at >= shows.airdate AND plays.played_at < datetime(shows.airdate, '+3 hours')"
      else
        "plays.played_at >= shows.airdate AND plays.played_at < (shows.airdate + INTERVAL '3 hours')"
      end

    joins(:show).where(condition)
  }
end

# app/models/play.rb
# app/models/play.rb
class Play < ApplicationRecord
  belongs_to :show, optional: true

  scope :for_program, ->(program_name) {
    joins(:show)
      .where(shows: { program_name: program_name })
      .where.not(artist: nil, song: nil)
  }

  scope :within_show_window, -> {
    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase
    condition =
      if adapter.include?("sqlite")
        "plays.played_at >= shows.airdate AND plays.played_at < datetime(shows.airdate, '+3 hours')"
      else
        "plays.played_at >= shows.airdate AND plays.played_at < (shows.airdate + INTERVAL '3 hours')"
      end

    joins(:show).where(condition)
  }

  # 🔥 New top songs helper — returns array instead of hash
  def self.top_songs_for(program_name, since:, limit: 40)
    for_program(program_name)
      .where("plays.played_at >= ?", since)
      .group(:artist, :song)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(limit)
      .count
      .map { |(artist, song), count| [artist, song, count] }
  end
end
