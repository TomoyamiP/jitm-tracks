class MorningController < ApplicationController
  def index
    @plays = Play.for_program("The Morning Show").order(played_at: :desc).limit(200)
  end

  def refresh
    client = KexpClient.new
    before = Play.count
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
