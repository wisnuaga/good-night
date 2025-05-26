class RepairSleepRecordCacheJob < ApplicationJob
  queue_as :default

  def perform(user_id, followee_ids)
    # Idempotency checking
    lock_key = "repair_lock:#{user_id}"
    locked = $redis.set(lock_key, true, nx: true, ex: 60)
    return unless locked

    repo = SleepRecordRepository.new
    existing_ids = repo.list_fanout(user_id: user_id) # default fetch without cursor
    correct_records = []
    cursor = nil

    while correct_records.size < SleepRecordRepository::FEED_LIST_LIMIT
      batch_limit = SleepRecordRepository::FEED_LIST_LIMIT - correct_records.size
      records = repo.list_by_user_ids(user_ids: followee_ids, cursor: cursor, limit: batch_limit)
      break if records.empty?

      correct_records.concat(records)
      cursor = records.last.clock_in.to_i
    end

    correct_records.uniq!(&:id)

    missing_records = correct_records.reject { |r| existing_ids.include?(r.id) }
    missing_records.each do |record|
      repo.add_to_feed(user_id: user_id, sleep_record: record)
    end
  rescue => e
    Rails.logger.error("[RepairSleepRecordCacheJob] Failed for user #{user_id}: #{e.message}")
  end
end
