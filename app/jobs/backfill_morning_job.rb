# app/jobs/backfill_morning_job.rb
class BackfillMorningJob < ApplicationJob
  queue_as :default

 def perform(days:, simulate: false)
  since = days.to_i.days.ago.beginning_of_day
  status = BackfillStatus.create!(
    days: days,
    started_at: Time.current,
    status: "running"
  )

  Rails.logger.info("[BackfillMorningJob] Starting backfill for last #{days} days (since #{since}) simulate=#{simulate}")

  imported =
    if simulate
      sleep 20 # simulate long-running job
      0        # nothing actually imported
    else
      KexpClient.new.import_morning_since!(since)
    end

  status.update!(
    finished_at: Time.current,
    imported_count: imported,
    status: "success"
  )

  Rails.logger.info("[BackfillMorningJob] Done: imported #{imported} plays for last #{days} days")
  rescue => e
    status.update!(
      finished_at: Time.current,
      status: "failed",
      error_message: "#{e.class}: #{e.message}"
    ) if status

    Rails.logger.error("[BackfillMorningJob] FAILED: #{e.class}: #{e.message}")
    raise
  end
end
