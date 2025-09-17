# lib/tasks/kexp.rake
namespace :kexp do
  # Helper: resolve the program_id for "The Morning Show"
  def morning_program_id(client)
    programs   = client.search_programs("Morning", limit: 50)
    morning    = programs.find { |p| p["name"].to_s.strip == "The Morning Show" }
    (morning && morning["id"]) || 16 # fallback to 16
  end

  desc "Import today's plays for The Morning Show"
  task import_morning_today: :environment do
    require 'date'
    client      = KexpClient.new
    program_id  = morning_program_id(client)

    puts "Using program_id=#{program_id} for The Morning Show"

    # Fetch recent shows for that program, then keep only today's Morning Show blocks
    shows = client.fetch_shows_for_program(program_id, limit: 30)
    today = Date.current

    todays_shows = shows.select do |s|
      begin
        Date.parse(s["start_time"]).to_date == today &&
          s["program_name"].to_s.strip == "The Morning Show"
      rescue
        false
      end
    end

    if todays_shows.empty?
      puts "No Morning Show found for #{today} (yet)."
      next
    end

    imported_counts = []
    todays_shows.each do |s|
      show_id = s["id"]
      puts "Importing plays for show ##{show_id} (#{s["program_name"]} at #{s["start_time"]})..."
      before = Play.count
      client.import_plays_for_show(show_id)
      after  = Play.count
      imported_counts << (after - before)
    end

    puts "Done. Imported #{imported_counts.sum} new play(s)."
  end

  desc "Import the most recent 'The Morning Show' block (skips other programs)"
  task import_morning_recent: :environment do
    client     = KexpClient.new
    program_id = morning_program_id(client)

    puts "Using program_id=#{program_id} for The Morning Show"

    shows = client.fetch_shows_for_program(program_id, limit: 30)

    # Pick the most recent entry that is actually "The Morning Show"
    recent_show = shows.find { |s| s["program_name"].to_s.strip == "The Morning Show" }

    if recent_show.nil?
      puts "No Morning Show found in recent shows."
      next
    end

    show_id = recent_show["id"]
    puts "Importing plays for show ##{show_id} (#{recent_show["program_name"]} at #{recent_show["start_time"]})..."
    before = Play.count
    client.import_plays_for_show(show_id)
    after  = Play.count
    puts "Done. Imported #{after - before} new play(s)."
  end

  # Nice alias so `rake kexp:import_morning` does today's import
  desc "Alias: Import today's plays for The Morning Show"
  task import_morning: :environment do
    Rake::Task["kexp:import_morning_today"].invoke
  end
end

# Backfill Morning Show for the last N days (default 30)
# Usage:
#   bin/rails "kexp:backfill_morning[DAYS]"        # positional arg
#   or: DAYS=45 bin/rails kexp:backfill_morning    # via ENV
namespace :kexp do
  desc "Backfill The Morning Show for the last N days (default: 30)"
  task :backfill_morning, [:days] => :environment do |t, args|
    require 'active_support/core_ext/numeric/time'
    days = (ENV["DAYS"] || args[:days] || 30).to_i
    since_time = days.days.ago

    client = KexpClient.new

    # Find program id (fallback to 16)
    programs = client.search_programs("Morning", limit: 50)
    morning  = programs.find { |p| p["name"].to_s.strip == "The Morning Show" }
    program_id = (morning && morning["id"]) || 16

    puts "Backfilling Morning Show since #{since_time} (#{days} days) using program_id=#{program_id}…"
    before = Play.count
    client.import_plays_for_program(program_id, since: since_time)
    puts "Done. Imported #{Play.count - before} new play(s)."
  end
end

# Import the latest N Morning Show shows (default 5), newest to oldest
# Useful when 'today' logic misses due to timezones, or you want a quick catch-up.
namespace :kexp do
  desc "Import latest N Morning Show shows (default: 5)"
  task :import_morning_latest, [:n] => :environment do |t, args|
    n = (ENV["N"] || args[:n] || 5).to_i

    client = KexpClient.new

    # Find program id (fallback to 16)
    programs = client.search_programs("Morning", limit: 50)
    morning  = programs.find { |p| p["name"].to_s.strip == "The Morning Show" }
    program_id = (morning && morning["id"]) || 16

    shows = client.fetch_shows_for_program(program_id, limit: n)
    puts "Importing latest #{shows.size} Morning Show block(s)…"
    total = 0
    shows.each do |s|
      show_id = s["id"]
      puts "  → Show ##{show_id} (#{s["program_name"]} at #{s["start_time"]})"
      before = Play.count
      client.import_plays_for_show(show_id)
      total += (Play.count - before)
    end
    puts "Done. Imported #{total} new play(s)."
  end
end
