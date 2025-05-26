class SleepRecordFanoutJob < ApplicationJob
  queue_as :default

  def perform(sleep_record_id, follower_ids)
    sleep_record = SleepRecord.find_by(id: sleep_record_id)
    return unless sleep_record

    # Use your repository method to fanout cache writes
    SleepRecordRepository.new.write_fanout(sleep_record: sleep_record, follower_ids: follower_ids)
  rescue => e
    Rails.logger.error("[SleepRecordFanoutJob] Failed for record #{sleep_record_id}: #{e.message}")
  end
end
