# app/jobs/backfill_morning_job.rb
class BackfillMorningJob < ApplicationJob
  queue_as :default

  def perform(days:)
    days_i = days.to_i.clamp(1, 365)
    since  = days_i.days.ago.beginning_of_day.in_time_zone
    status = BackfillStatus.create!(
      days:           days_i,
      started_at:     Time.current,
      status:         "running",
      imported_count: 0
    )

    Rails.logger.info("[BackfillMorningJob] Starting backfill for last #{days_i} days (since #{since})")

    imported = 0
    begin
      client   = KexpClient.new
      imported = client.import_morning_since!(since).to_i # handles nil
      status.update!(
        imported_count: imported,
        status:         "success",
        finished_at:    Time.current
      )
      Rails.logger.info("[BackfillMorningJob] Done: imported #{imported} plays for last #{days_i} days")
    rescue => e
      # mark this run as failed with message
      begin
        status.update!(
          status:         "failed",
          error_message:  "#{e.class}: #{e.message}",
          finished_at:    Time.current,
          imported_count: imported
        )
      rescue StandardError
        # best-effort: avoid masking the original error
      end
      Rails.logger.error("[BackfillMorningJob] FAILED: #{e.class}: #{e.message}")
      raise
    ensure
      # If the dyno killed us mid-run (or we exited early) and status is still 'running', mark as stale failure.
      begin
        status.reload
        if status.status == "running"
          status.update!(
            status:         "failed",
            error_message:  "terminated before completion",
            finished_at:    Time.current,
            imported_count: imported
          )
        end
      rescue StandardError
        # swallow to avoid masking original errors
      end
    end
  end
end
