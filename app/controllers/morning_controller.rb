# app/controllers/morning_controller.rb
class MorningController < ApplicationController
  def index
    @period = params[:period].to_s
    since   = since_for(@period)

    # Top 40 for selected period
    @top_songs = Play.top_songs_for("The Morning Show", since: since, limit: 40)

    # Count for header
    @period_play_count = period_play_count(since)

    # Recent plays (dedup near-identicals within the same minute)
    rel = Play.for_program("The Morning Show").within_show_window.order(played_at: :desc).limit(400)
    seen = {}
    filtered = []
    rel.each do |p|
      minute_key = p.played_at&.in_time_zone('Pacific Time (US & Canada)')&.strftime('%Y-%m-%d %H:%M')
      key = [p.show_id, p.artist, p.song, minute_key]
      next if seen[key]
      seen[key] = true
      filtered << p
    end
    @plays = filtered.first(200)
  end

  # Turbo-updated Top 40 frame
  def top
    period = params[:period].to_s
    since  = since_for(period)

    top_songs = Play.top_songs_for("The Morning Show", since: since, limit: 40)
    @period_play_count = period_play_count(since)

    # Always return a <turbo-frame id="top40"> so Turbo can replace it
    html = view_context.turbo_frame_tag("top40") do
      render_to_string(partial: "top40", locals: { top_songs: top_songs, period: period })
    end
    render html: html.html_safe
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

  private

  def since_for(period)
    case period
    when "90", "90d" then 90.days.ago
    when "365", "1y" then 1.year.ago
    when "all"       then nil
    else                  30.days.ago
    end
  end

  # Count plays for the selected window (no 3h show window restriction)
  def period_play_count(since)
    rel = Play.for_program("The Morning Show")
    rel = rel.where("plays.played_at >= ?", since) if since.present?
    rel.count
  end
end
