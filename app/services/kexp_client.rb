# app/services/kexp_client.rb
# Service for fetching KEXP plays from the API
require 'httparty'

class KexpClient
  include HTTParty
  base_uri 'https://api.kexp.org/v2'

  def fetch_recent_plays(limit: 20)
    self.class.get('/plays/', query: { limit: limit })
  end
end
