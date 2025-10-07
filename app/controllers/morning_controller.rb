# app/controllers/morning_controller.rb
class MorningController < ApplicationController
  def index
    @period = params[:period].to_s
    @years  = years_list

    @last_backfill = BackfillStatus.order(created_at: :desc).first

    rel, label = plays_relation_for(@period)

    # Top 40 + header bits
    @top_songs = rel
      .group(:artist, :song)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(40)
      .count
      .map { |(artist, song), count| [artist, song, count] }

    @period_play_count = rel.count
    @period_label      = label

    # Recent plays (dedup near-identicals within the same minute)
    recent_rel = Play
      .for_program("The Morning Show")
      .within_show_window
      .order(played_at: :desc)
      .limit(400)

    seen = {}
    filtered = []
    recent_rel.each do |p|
      minute_key = p.played_at&.in_time_zone('Pacific Time (US & Canada)')&.strftime('%Y-%m-%d %H:%M')
      key = [p.show_id, p.artist, p.song, minute_key]
      next if seen[key]
      seen[key] = true
      filtered << p
    end
    @plays = filtered.first(200)
  end

  # Turbo-updated Top 40 frame (buttons and table live in the partial)
  def top
    @backfill = BackfillStatus.order(started_at: :desc).first
    period = params[:period].to_s
    years  = years_list

    rel, label = plays_relation_for(period)

    top_songs = rel
      .group(:artist, :song)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(40)
      .count
      .map { |(artist, song), count| [artist, song, count] }

    period_play_count = rel.count

    render html: view_context.turbo_frame_tag("top40") {
      render_to_string(
        partial: "top40",
        locals: {
          top_songs:         top_songs,
          period:            period,
          period_label:      label,
          period_play_count: period_play_count,
          years:             years
        }
      )
    }.html_safe
  end

  def refresh
    # Kick off a quick background fetch for today (doesn't block the web request)
    BackfillMorningJob.perform_later(days: 1)

    redirect_to morning_index_path, notice: "Refreshing in the background… check back in about a minute."
  rescue => e
    redirect_to morning_index_path, alert: "Refresh started, but reported: #{e.class}: #{e.message}"
  end

  def backfill
    days = (params[:days] || 30).to_i
    BackfillMorningJob.perform_later(days: days)
    redirect_to morning_index_path, notice: "Backfill started for last #{days} days. Check logs for progress."
  end

  private

  # Build the year list based on your data; fallback to 2015..current year.
  def years_list
    min_year   = Play.for_program("The Morning Show").minimum(:played_at)&.year
    start_year = [min_year || 2015, 2015].max
    (start_year..Time.zone.now.year).to_a.reverse
  end

  # Returns [relation, label] for the selected period string.
  # Supported:
  #   nil/"30" → last 30 days
  #   "90"     → last 90 days
  #   "365"    → last 365 days
  #   "all"    → all time
  #   "year-YYYY" → that calendar year
  def plays_relation_for(period)
    base = Play.for_program("The Morning Show")

    case period
    when "90", "90d"
      [base.where("plays.played_at >= ?", 90.days.ago), "Last 90 Days"]
    when "365", "1y"
      [base.where("plays.played_at >= ?", 1.year.ago), "Last Year"]
    when /\Ayear-(\d{4})\z/
      y      = Regexp.last_match(1).to_i
      start  = Time.zone.local(y, 1, 1).beginning_of_day
      finish = Time.zone.local(y, 12, 31).end_of_day
      [base.where(played_at: start..finish), y.to_s]
    when "all"
      [base, "All Time"]
    else
      [base.where("plays.played_at >= ?", 30.days.ago), "Last 30 Days"]
    end
  end
end
