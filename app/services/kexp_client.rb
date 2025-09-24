# app/services/kexp_client.rb
require "httparty"
require "time"
require "date"

class KexpClient
  include HTTParty
  base_uri "https://api.kexp.org/v2"
  format :json

  MORNING_PROGRAM_FALLBACK_ID = 16
  MORNING_PROGRAM_NAME        = "The Morning Show"

  # ---------------------------------------------------------------------------
  # Helpers
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
        s.start_with?("http") ? s : "/shows/#{s}/"
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
    get_results("/plays/", { limit: limit })
  end

  def search_programs(q, limit: 20)
    get_results("/programs/", { search: q, limit: limit })
  end

  def fetch_shows_for_program(program_id, limit: 50, offset: 0)
    get_results("/shows/", { program: program_id, limit: limit, offset: offset })
  end

  def fetch_plays_for_show(show_id, limit: 50, offset: 0)
    get_results("/plays/", { show: show_id, limit: limit, offset: offset })
  end

  # ✅ NEW: fetch plays using a date range (oldest → newest)
  def fetch_plays_by_airdate(from:, to:, limit: 200, offset: 0)
    get_results("/plays/", {
      airdate_after:  from.iso8601,
      airdate_before: to.iso8601,
      ordering:       "airdate",  # oldest → newest
      limit:          limit,
      offset:         offset
    })
  end

  # ---------------------------------------------------------------------------
  # Importers
  # ---------------------------------------------------------------------------

  # Import N most recent plays (across all programs).
  def import_recent_plays(limit: 20)
    fetch_recent_plays(limit: limit).each do |play|
      show_id = play["show_uri"]&.split("/")&.last&.to_i
      show    = nil

      if show_id&.positive?
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
  # Always returns number of new rows created.
  def import_plays_for_show(show_id)
    plays = fetch_plays_for_show(show_id, limit: 200)
    plays = [] unless plays.is_a?(Array)

    # Fetch show details
    show_details = fetch_show("https://api.kexp.org/v2/shows/#{show_id}/")

    # Skip if not Morning Show
    unless show_details && show_details["program_name"].to_s.strip == MORNING_PROGRAM_NAME
      Rails.logger.info("Skipping show ##{show_id} (#{show_details && show_details['program_name']}) – not #{MORNING_PROGRAM_NAME}")
      return 0
    end

    # Ensure we have a Show record
    show = Show.find_or_initialize_by(kexp_show_id: show_id)
    show.uri          = show_details["uri"]
    show.program_name = show_details["program_name"]
    show.host_names   = Array(show_details["host_names"]).join(", ")
    show.airdate      = show_details["start_time"]
    show.save!

    created = 0
    plays.each do |play|
      next if play["artist"].blank? || play["song"].blank?

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
          rec     = Play.find_or_initialize_by(kexp_play_id: play["id"])
          was_new = rec.new_record?
          rec.assign_attributes(attrs)
          rec.save!
          created += 1 if was_new
        else
          Play.create!(attrs)
          created += 1
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
        raise unless e.message =~ /unique|duplicate/i
      end
    end

    created
  end

  # Import plays for every show in a program since a given time.
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

  # Import all plays for today's Morning Show blocks.
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

  # Backfill Morning Show plays since a given date, with correct pagination.
  # If dry_run: true, nothing is saved — just counts how many rows would be created.
  def import_morning_since!(since_date, dry_run: false)
    programs   = search_programs("Morning", limit: 50)
    morning    = programs.find { |p| p["name"].to_s.strip == MORNING_PROGRAM_NAME }
    program_id = (morning && morning["id"]) || MORNING_PROGRAM_FALLBACK_ID

    puts "Using program_id=#{program_id} for #{MORNING_PROGRAM_NAME} (backfill since #{since_date})"

    imported = 0
    offset   = 0
    # KEXP API effectively caps this at 50 — do not set higher.
    per_page = 50

    loop do
      shows = fetch_shows_for_program(program_id, limit: per_page, offset: offset)
      break if shows.blank?

      shows.each do |s|
        start_time =
          begin
            Time.parse(s["start_time"])
          rescue
            nil
          end
        next unless start_time
        next if start_time < since_date
        next unless s["program_name"].to_s.strip == MORNING_PROGRAM_NAME

        if dry_run
          plays = fetch_plays_for_show(s["id"], limit: 200)
          plays = [] unless plays.is_a?(Array)
          plays.reject! { |p| p["artist"].blank? || p["song"].blank? }
          imported += plays.size
        else
          before = Play.count
          import_plays_for_show(s["id"])
          imported += (Play.count - before)
        end
      end

      # Advance by what we actually received so we don’t skip pages.
      offset += shows.size

      # Safety: if API keeps returning the same page, bail to avoid an infinite loop.
      break if shows.size < per_page
    end

    imported
  end

  # ✅ NEW: Backfill Morning Show plays for an arbitrary date window via /plays
  # from:, to: are Time/Date/DateTime; returns number of new rows
  def import_morning_range!(from:, to:, dry_run: false)
    raise ArgumentError, "from must be < to" if from >= to

    per_page   = 200
    offset     = 0
    imported   = 0
    show_cache = {} # { show_id => show_details_hash }

    loop do
      batch = fetch_plays_by_airdate(from: from, to: to, limit: per_page, offset: offset)
      break if batch.blank?

      batch.each do |play|
        # Skip blanks fast
        next if play["artist"].blank? || play["song"].blank?

        # Resolve show id and details (with cache)
        show_id = play["show_uri"]&.split("/")&.last&.to_i
        next unless show_id && show_id > 0

        details = show_cache[show_id]
        unless details
          details = fetch_show(play["show_uri"]) || {}
          show_cache[show_id] = details
        end

        # Only import Morning Show
        next unless details["program_name"].to_s.strip == MORNING_PROGRAM_NAME

        # Ensure Show row
        show = Show.find_or_initialize_by(kexp_show_id: show_id)
        show.uri          = details["uri"] || play["show_uri"]
        show.program_name = details["program_name"]
        show.host_names   = Array(details["host_names"]).join(", ")
        show.airdate      = details["start_time"]
        show.save! if show.changed?

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

        if dry_run
          imported += 1
        else
          if play["id"].present?
            rec     = Play.find_or_initialize_by(kexp_play_id: play["id"])
            was_new = rec.new_record?
            rec.assign_attributes(attrs)
            rec.save!
            imported += 1 if was_new
          else
            Play.create!(attrs)
            imported += 1
          end
        end
      end

      offset += per_page
    end

    imported
  end
end
