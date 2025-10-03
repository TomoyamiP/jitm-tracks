# app/jobs/backfill_morning_job.rb
class BackfillMorningJob < ApplicationJob
  queue_as :default

  def perform(days:)
    since = days.to_i.days.ago.beginning_of_day
    Rails.logger.info("[BackfillMorningJob] starting since=#{since}")
    client = KexpClient.new
    imported = client.import_morning_since!(since)
    Rails.logger.info("[BackfillMorningJob] done imported=#{imported}")
  rescue => e
    Rails.logger.error("[BackfillMorningJob] ERROR #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
  end
end
