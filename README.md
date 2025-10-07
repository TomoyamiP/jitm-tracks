# JITMtracks

JITMtracks is a Rails app that archives and displays playlists from **The Morning Show** on [KEXP](https://www.kexp.org/).  
It pulls track plays directly from the KEXP API, storing them locally so you can browse recent plays, explore historical data, and view Top 40 charts across different time ranges.

The database currently covers **every Morning Show play since January 2015**, giving you over a decade of music history to explore.

---

## ✨ Features
- **Recent Plays** – Live feed of what’s been played on The Morning Show  
- **Top 40 Charts** – Switch between last 30 days, 90 days, 1 year, or all-time  
- **Daily Auto-Update** – Scheduler keeps today’s playlist fresh automatically  
- **Non-blocking Refresh** – Refresh Today runs in the background (no timeouts)  
- **Turbo-powered UI** – Smooth frame updates for fast navigation  

---

## 🛠️ Tech Stack
- Ruby on Rails 7  
- PostgreSQL  
- Turbo / Hotwire  
- SCSS for styling  
- Deployed on Heroku (Eco dyno + Postgres essential-0 + free Scheduler)  

---

## 📅 Data Coverage
- Morning Show plays starting from **January 2015 → present**  

---

## 👤 Author
Built by [Paul Miyamoto](https://github.com/TomoyamiP) as both a technical challenge and a way to preserve the music that shaped his daily life in Seattle.

---

## 🧰 Developer Utilities
These are optional commands for maintenance and recovery.  

- **Manual 30-day backfill (rarely needed):**
  ```bash
  heroku run -a jitm-tracks rails runner 'BackfillMorningJob.perform_now(days: 30)'

---

## 🚀 Deployment Notes

- **Heroku App**: `jitm-tracks`
  - Eco dyno (web), Postgres essential-0, free Scheduler
- **Database**:
  - Migrated with `rails db:migrate`
  - Imported local snapshot once via `pg:reset + pg:push`
- **Assets/UI**:
  - Fixed asset pipeline (application.scss + manifest)
  - Root = Morning page, Turbo frame for Top 40
  - UI polish: nav links, press logo, hover/scale effects, modal close button, warning banners
- **Background Jobs**:
  - `BackfillMorningJob` + `BackfillStatus` model
  - One-off dynos: run with `rails runner 'BackfillMorningJob.perform_now(days: X)'`
  - Refresh button updated to run jobs in background (no H12 timeouts)
  - Status banner shows last job (⏳ running / ✅ success / ⚠️ failed)
- **Automation**:
  - Heroku Scheduler runs daily:
    ```bash
    rails runner 'BackfillMorningJob.perform_now(days: 1)'
    ```
  - Auto-updates the database + banner without downtime
