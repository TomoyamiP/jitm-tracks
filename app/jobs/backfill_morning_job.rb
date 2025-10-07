# app/jobs/backfill_morning_job.rb
class BackfillMorningJob < ApplicationJob
  queue_as :default

  def perform(days:)
    since  = days.to_i.days.ago.beginning_of_day
    status = BackfillStatus.create!(
      days: days,
      started_at: Time.current,
      status: "running",
      imported_count: 0
    )

    Rails.logger.info("[BackfillMorningJob] Starting backfill for last #{days} days (since #{since})")

    imported = 0
    begin
      client   = KexpClient.new
      imported = client.import_morning_since!(since).to_i
      status.update!(imported_count: imported, status: "success", finished_at: Time.current)
      Rails.logger.info("[BackfillMorningJob] Done: imported #{imported} plays for last #{days} days")
    rescue => e
      status.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}",
        finished_at: Time.current
      ) rescue nil
      Rails.logger.error("[BackfillMorningJob] FAILED: #{e.class}: #{e.message}")
      raise
    ensure
      # If something killed the job before reaching success/failed, close it as failed(stale)
      if status && status.status == "running"
        status.update!(
          status: "failed",
          error_message: "terminated before completion",
          finished_at: Time.current,
          imported_count: imported
        ) rescue nil
      end
    end
  end
end
