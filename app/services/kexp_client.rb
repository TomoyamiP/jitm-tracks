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
      Play.find_or_create_by!(kexp_play_id: play["id"]) do |p|
        p.song          = play["song"]
        p.artist        = play["artist"]
        p.album         = play["album"]
        p.play_type     = play["play_type"]
        p.played_at     = play["airdate"]
        p.thumbnail_uri = play["thumbnail_uri"]
        p.show_uri      = play["show_uri"]
        # These fields might be absent in /plays/ — handle nils safely:
        p.program_name  = play["program_name"] if play["program_name"]
        p.host_names    = Array(play["host_names"]).join(", ") if play["host_names"]
      end
    end
  end
end
