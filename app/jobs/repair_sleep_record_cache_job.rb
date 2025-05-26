class RepairSleepRecordCacheJob < ApplicationJob
  queue_as :default

  def perform(user_id, followee_ids)
    lock_key = "repair_lock:#{user_id}"
    locked = $redis.set(lock_key, true, nx: true, ex: 60) # avoid duplicate repair jobs
    return unless locked

    repo = SleepRecordRepository.new
    redis_key = "feed:#{user_id}"
    existing_ids = repo.list_fanout(user_id: user_id)
    correct_records = []
    cursor = nil

    while correct_records.size < SleepRecordRepository::FEED_LIST_LIMIT
      batch_limit = SleepRecordRepository::FEED_LIST_LIMIT - correct_records.size
      records = repo.list_by_user_ids(user_ids: followee_ids, cursor: cursor, limit: batch_limit)
      break if records.empty?

      correct_records.concat(records)
      cursor = records.last.clock_in
    end

    correct_records.uniq!(&:id)

    missing_records = correct_records.reject { |r| existing_ids.include?(r.id) }
    missing_records.each do |record|
      $redis.zadd(redis_key, record.clock_in.to_i, record.id)
    end

    # Trim older records to respect feed limit
    $redis.zremrangebyrank(redis_key, 0, -SleepRecordRepository::FEED_LIST_LIMIT - 1)
    $redis.expire(redis_key, SleepRecordRepository::FEED_TTL_SECONDS)
  rescue => e
    Rails.logger.error("[RepairSleepRecordCacheJob] Failed for user #{user_id}: #{e.message}")
  end
end
