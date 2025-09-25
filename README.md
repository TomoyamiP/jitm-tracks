# jitm-tracks
🎵 John in The Morning Tracks

A Rails app that tracks and displays plays from KEXP’s The Morning Show, with features to backfill historical data, refresh today’s set, and view Top 40 tracks by time period.

✨ Features
	•	Recent Plays — See what was just played on The Morning Show
	•	Top 40 Charts — View the most-played tracks over the last 30 days, 90 days, 1 year, or all-time
	•	Backfill — Import historical plays going back to 2010 (via KEXP’s public API)
	•	Refresh Today — Instantly pull in the latest Morning Show plays
	•	Turbo Frames — Fast updates when switching between Top 40 periods
	•	About Modal — Info about the project and personal story

🛠️ Tech Stack
	•	Ruby on Rails 7 (Hotwire + Turbo)
	•	PostgreSQL (for storing plays + shows)
	•	HTTParty (API integration with KEXP)
	•	Bootstrap-style SCSS (custom styling + responsive tables)

🚀 Getting Started
git clone https://github.com/TomoyamiP/jitm-tracks.git
cd jitm-tracks
bundle install
bin/rails db:create db:migrate
bin/rails s

💡 Why This Project?

I’m from Seattle, and KEXP was part of home for me. The Morning Show was my daily soundtrack during commutes, and every Friday the Mint Royale “Show Me” track was something I looked forward to. Building this project is both a technical challenge and a way to archive that connection.

🔗 Links
	•	🎧 KEXP.org
	•	💻 My GitHub
