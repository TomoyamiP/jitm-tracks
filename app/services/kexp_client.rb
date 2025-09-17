# app/services/kexp_client.rb
require 'httparty'
require 'time'
require 'date'

class KexpClient
  include HTTParty
  base_uri 'https://api.kexp.org/v2'
  format :json

  MORNING_PROGRAM_FALLBACK_ID = 16
  MORNING_PROGRAM_NAME        = "The Morning Show"

  # ---------------------------------------------------------------------------
  # Small helpers
  # ---------------------------------------------------------------------------

  def get_results(path_or_url, query = {})
    res  = self.class.get(path_or_url, query: query)
    body = res.parsed_response
    body.is_a?(Hash) ? (body["results"] || []) : (body || [])
  rescue StandardError
    []
  end

  # Accepts a show id (Integer) OR a full show URI (String)
  def fetch_show(show_uri_or_id)
    url =
      case show_uri_or_id
      when Integer
        "/shows/#{show_uri_or_id}/"
      else
        s = show_uri_or_id.to_s
        s.start_with?('http') ? s : "/shows/#{s}/"
      end
    res = self.class.get(url)
    res.parsed_response
  rescue StandardError
    nil
  end

  # ---------------------------------------------------------------------------
  # Raw fetchers
  # ---------------------------------------------------------------------------

  def fetch_recent_plays(limit: 20)
    get_results('/plays/', { limit: limit })
  end

  def search_programs(q, limit: 20)
    get_results('/programs/', { search: q, limit: limit })
  end

  def fetch_shows_for_program(program_id, limit: 50, offset: 0)
    get_results('/shows/', { program: program_id, limit: limit, offset: offset })
  end

  def fetch_plays_for_show(show_id, limit: 50, offset: 0)
    get_results('/plays/', { show: show_id, limit: limit, offset: offset })
  end

  # ---------------------------------------------------------------------------
  # Importers
  # ---------------------------------------------------------------------------

  def import_recent_plays(limit: 20)
    fetch_recent_plays(limit: limit).each do |play|
      show_id = play["show_uri"]&.split("/")&.last&.to_i
      show    = nil

      if show_id && show_id > 0
        details = fetch_show(play["show_uri"])
        show = Show.find_or_initialize_by(kexp_show_id: show_id)
        show.uri          = details&.dig("uri") || play["show_uri"]
        show.program_name = details&.dig("program_name")
        show.host_names   = Array(details&.dig("host_names")).join(", ")
        show.airdate      = details&.dig("start_time")
        show.save!
      end

      Play.find_or_create_by!(kexp_play_id: play["id"]) do |p|
        p.song          = play["song"]
        p.artist        = play["artist"]
        p.album         = play["album"]
        p.play_type     = play["play_type"]
        p.played_at     = play["airdate"]
        p.thumbnail_uri = play["thumbnail_uri"]
        p.show_uri      = play["show_uri"]
        p.show          = show if show
      end
    end
  end

  # Import all plays for a specific show.
  # ✅ Always returns an Integer: number of new rows created.
  def import_plays_for_show(show_id)
    plays = fetch_plays_for_show(show_id, limit: 200)
    plays = [] unless plays.is_a?(Array) # guard

    # Ensure we have a Show record first
    show_details = fetch_show("https://api.kexp.org/v2/shows/#{show_id}/")

    # Only import Morning Show
    unless show_details && show_details["program_name"].to_s.strip == MORNING_PROGRAM_NAME
      Rails.logger.info("Skipping show ##{show_id} (#{show_details && show_details['program_name']}) – not #{MORNING_PROGRAM_NAME}")
      return 0
    end

    show = Show.find_or_initialize_by(kexp_show_id: show_id)
    show.uri          = show_details["uri"]
    show.program_name = show_details["program_name"]
    show.host_names   = Array(show_details["host_names"]).join(", ")
    show.airdate      = show_details["start_time"]
    show.save!

    created = 0
    plays.each do |play|
      # 1) Skip blanks fast
      next if play["artist"].blank? || play["song"].blank?

      # 2) Common attrs
      attrs = {
        song:          play["song"],
        artist:        play["artist"],
        album:         play["album"],
        play_type:     play["play_type"],
        played_at:     play["airdate"],
        thumbnail_uri: play["thumbnail_uri"],
        show_uri:      play["show_uri"],
        show:          show
      }

      begin
        if play["id"].present?
          rec = Play.find_or_initialize_by(kexp_play_id: play["id"])
          was_new = rec.new_record?
          rec.assign_attributes(attrs)
          rec.save!
          created += 1 if was_new
        else
          Play.create!(attrs)
          created += 1
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
        # Unique index collision -> already imported by another path; ignore.
        raise unless e.message =~ /unique|duplicate/i
      end
    end

    created
  end

  # Import plays for every show in a program since a given time.
  # ✅ Sums the integer returned by import_plays_for_show.
  def import_plays_for_program(program_id, since: 1.month.ago)
    shows = fetch_shows_for_program(program_id, limit: 200)
    total = 0

    shows.each do |s|
      start_time = (Time.parse(s["start_time"]) rescue nil)
      next if since && start_time && start_time < since
      total += import_plays_for_show(s["id"]).to_i
    end

    total
  end

  # One-shot: import all plays for today's Morning Show blocks.
  # ✅ Returns integer count.
  def import_morning_today!
    programs   = search_programs("Morning", limit: 50)
    morning    = programs.find { |p| p["name"].to_s.strip == MORNING_PROGRAM_NAME }
    program_id = (morning && morning["id"]) || MORNING_PROGRAM_FALLBACK_ID

    shows = fetch_shows_for_program(program_id, limit: 20)
    today = Date.current

    todays_shows = shows.select do |s|
      begin
        Date.parse(s["start_time"]).to_date == today &&
          s["program_name"].to_s.strip == MORNING_PROGRAM_NAME
      rescue
        false
      end
    end

    todays_shows.sum { |s| import_plays_for_show(s["id"]).to_i }
  end

  # Backfill Morning Show plays since a given date/time.
  # Example: client.import_morning_since!(30.days.ago)
  # ✅ Returns integer count.
  def import_morning_since!(since_date)
    programs   = search_programs("Morning", limit: 50)
    morning    = programs.find { |p| p["name"].to_s.strip == MORNING_PROGRAM_NAME }
    program_id = (morning && morning["id"]) || MORNING_PROGRAM_FALLBACK_ID

    puts "Using program_id=#{program_id} for #{MORNING_PROGRAM_NAME} (backfill since #{since_date})"

    shows = fetch_shows_for_program(program_id, limit: 200)
    backfill_shows = shows.select do |s|
      begin
        Time.parse(s["start_time"]) >= since_date
      rescue
        false
      end
    end

    backfill_shows.sum do |s|
      puts "Importing plays for show ##{s["id"]} (#{s["program_name"]} at #{s["start_time"]})..."
      import_plays_for_show(s["id"]).to_i
    end
  end
end
