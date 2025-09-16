# lib/tasks/kexp.rake
namespace :kexp do
  desc "Import today's plays for The Morning Show"
  task import_morning_today: :environment do
    require 'date'

    client = KexpClient.new

    # 1) Find the program id for "The Morning Show" (fallback to 16 if API wording shifts)
    programs = client.search_programs("Morning", limit: 50)
    morning   = programs.find { |p| p["name"].to_s.strip == "The Morning Show" }
    program_id = (morning && morning["id"]) || 16

    puts "Using program_id=#{program_id} for The Morning Show"

    # 2) Fetch recent shows for that program, then keep only today's
    shows = client.fetch_shows_for_program(program_id, limit: 20)
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

    # 3) Import plays for each of today's Morning Show blocks
    imported_counts = []
    todays_shows.each do |s|
      show_id = s["id"]
      puts "Importing plays for show ##{show_id} (#{s["program_name"]} at #{s["start_time"]})..."
      before = Play.count
      client.import_plays_for_show(show_id)
      after  = Play.count
      imported_counts << (after - before)
    end

    total = imported_counts.sum
    puts "Done. Imported #{total} new play(s)."
  end
end
