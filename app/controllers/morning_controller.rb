class MorningController < ApplicationController
  def index
    @plays = Play
      .joins(:show)
      .where(shows: { program_name: "The Morning Show" })
      .where(play_type: "trackplay")                 # only songs
      .where.not(artist: [nil, ""], song: [nil, ""]) # hide blanks
      .order(played_at: :desc)                       # newest first
      .limit(100)                                    # keep page light
  end
end
