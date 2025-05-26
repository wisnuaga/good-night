class RebuildSleepRecordCacheJob < ApplicationJob
  queue_as :default

  def perform(user_id, follower_ids)
    sleep_record_repository = SleepRecordRepository.new

    records = sleep_record_repository.list_by_user_id(user_id: user_id)

    records.each do |record|
      sleep_record_repository.fanout_to_followers(sleep_record: record, follower_ids: follower_ids)
    end
  rescue => e
    Rails.logger.error("[RebuildFeedCacheJob] Failed to rebuild cache for user #{user_id}: #{e.message}")
  end
end
