# app/controllers/morning_controller.rb
class MorningController < ApplicationController
  def index
    # ----- Top 40 period -----
    period = params[:period].to_s

    since =
      case period
      when "90", "90d"   then 90.days.ago
      when "365", "1y"   then 1.year.ago
      when "all"         then nil
      else                    30.days.ago # default 30 days
      end

    @top_songs = Play.top_songs_for("The Morning Show", since: since, limit: 40)

    # ----- Recent Plays (dedup near-identicals within the same minute) -----
    rel = Play
      .for_program("The Morning Show")
      .within_show_window
      .order(played_at: :desc)
      .limit(400)

    rows = rel.to_a
    seen = {}
    filtered = []

    rows.each do |p|
      minute_key = p.played_at&.in_time_zone('Pacific Time (US & Canada)')&.strftime('%Y-%m-%d %H:%M')
      key = [p.show_id, p.artist, p.song, minute_key]
      next if seen[key]
      seen[key] = true
      filtered << p
    end

    @plays = filtered.first(200)
  end

  def refresh
    client  = KexpClient.new
    before  = Play.count
    client.import_morning_today!
    imported = Play.count - before
    redirect_to morning_index_path, notice: "Morning show updated (#{imported} new plays)."
  rescue => e
    redirect_to morning_index_path, alert: "Refresh failed: #{e.class}: #{e.message}"
  end

  def backfill
    days   = (params[:days] || 30).to_i
    since  = days.days.ago.beginning_of_day
    client = KexpClient.new
    imported = client.import_morning_since!(since)
    redirect_to morning_index_path, notice: "Backfilled last #{days} days: imported #{imported} new play(s)."
  rescue => e
    redirect_to morning_index_path, alert: "Backfill failed: #{e.class}: #{e.message}"
  end
end
