# app/models/play.rb
class Play < ApplicationRecord
  belongs_to :show, optional: true

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
