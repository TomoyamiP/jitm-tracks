# app/services/kexp_client.rb
require 'httparty'

class KexpClient
  include HTTParty
  base_uri 'https://api.kexp.org/v2'

  def fetch_recent_plays(limit: 20)
    response = self.class.get('/plays/', query: { limit: limit })
    response.parsed_response["results"]
  end

  def import_recent_plays(limit: 20)
    fetch_recent_plays(limit: limit).each do |play|
      # Get show_id from the URI (last number in the URL)
      show_id = play["show_uri"]&.split("/")&.last&.to_i

      show = Show.find_or_create_by!(kexp_show_id: show_id) do |s|
        s.uri          = play["show_uri"]
        details        = fetch_show(play["show_uri"])
        if details
          s.program_name = details["program_name"]
          s.host_names   = Array(details["host_names"]).join(", ")
          s.airdate      = details["start_time"]
        end
      end if show_id

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

  def fetch_show(show_uri)
    return nil unless show_uri
    response = self.class.get(show_uri) # use full URL
    response.parsed_response
  end

  def search_programs(q, limit: 20)
    res = self.class.get('/programs/', query: { search: q, limit: limit })
    res.parsed_response["results"]
  end

  # List shows for a given program (e.g., MORNING_PROGRAM_ID)
  def fetch_shows_for_program(program_id, limit: 50, offset: 0)
    res = self.class.get('/shows/', query: { program: program_id, limit: limit, offset: offset })
    res.parsed_response["results"]
  end

  # Get plays for a specific show instance (by show_id)
  def fetch_plays_for_show(show_id, limit: 50, offset: 0)
    res = self.class.get('/plays/', query: { show: show_id, limit: limit, offset: offset })
    res.parsed_response["results"]
  end

  # Import all plays for a given show_id into the database
  def import_plays_for_show(show_id)
    plays = fetch_plays_for_show(show_id, limit: 200)
    return if plays.blank?

    # Ensure we have a Show record first
    show_details = fetch_show("https://api.kexp.org/v2/shows/#{show_id}/")
    show = Show.find_or_initialize_by(kexp_show_id: show_id)
    if show_details
      show.uri          = show_details["uri"]
      show.program_name = show_details["program_name"]
      show.host_names   = Array(show_details["host_names"]).join(", ")
      show.airdate      = show_details["start_time"]
      show.save!
    end

    plays.each do |play|
      next unless play # skip nils
      Play.find_or_create_by!(kexp_play_id: play["id"]) do |p|
        p.song          = play["song"]
        p.artist        = play["artist"]
        p.album         = play["album"]
        p.play_type     = play["play_type"]
        p.played_at     = play["airdate"]
        p.thumbnail_uri = play["thumbnail_uri"]
        p.show_uri      = play["show_uri"]
        p.show          = show
      end
    end
  end

  # Import all plays for a program (e.g. The Morning Show)
  # program_id: the KEXP program ID (16 for The Morning Show)
  # since: a Time or Date — only fetch shows starting after this
  def import_plays_for_program(program_id, since: 1.month.ago)
    shows = fetch_shows_for_program(program_id, limit: 200)

    shows.each do |s|
      start_time = Time.parse(s["start_time"]) rescue nil
      next if since && start_time && start_time < since

      import_plays_for_show(s["id"])
    end
  end
end
