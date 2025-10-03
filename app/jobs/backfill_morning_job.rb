# app/jobs/backfill_morning_job.rb
class BackfillMorningJob < ApplicationJob
  queue_as :default

  # Run the Morning Show backfill for the last `days` days.
  def perform(days:)
    since = days.to_i.days.ago.beginning_of_day
    Rails.logger.info("[BackfillMorningJob] Starting backfill for last #{days} days (since #{since})")

    client   = KexpClient.new
    imported = client.import_morning_since!(since)

    Rails.logger.info("[BackfillMorningJob] Done: imported #{imported} plays for last #{days} days")
  rescue => e
    Rails.logger.error("[BackfillMorningJob] FAILED: #{e.class}: #{e.message}")
    raise
  end
end
