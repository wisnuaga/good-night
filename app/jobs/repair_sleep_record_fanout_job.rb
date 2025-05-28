class RepairSleepRecordFanoutJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    lock_key = "repair_lock:#{user_id}"
    locked = $redis.set(lock_key, true, nx: true, ex: 60)
    return unless locked

    sleep_record_repo = SleepRecordRepository.new
    fanout_repo = FanoutRepository.new
    follow_repository = FollowRepository.new

    existing_ids = fanout_repo.list_fanout(user_id: user_id)
    correct_records = []

    first = true
    followee_cursor = nil
    cursor_time = nil

    loop do
      followee_ids, followee_cursor = follow_repository.list_followee_ids_batch(
        user_id: user_id,
        cursor: followee_cursor,
        limit: Repository::FANOUT_LIMIT
      )

      # include self on first loop only
      if first
        followee_ids << user_id
        first = false
      end

      break if followee_ids.empty?

      batch_limit = SleepRecordRepository::FEED_LIST_LIMIT - correct_records.size
      break if batch_limit <= 0

      records = sleep_record_repo.list_by_user_ids(
        user_ids: followee_ids,
        cursor: cursor_time,
        limit: batch_limit
      )

      break if records.empty?

      correct_records.concat(records)
      correct_records.uniq!(&:id)
      cursor_time = records.last.sleep_time

      break if followee_cursor.nil? || correct_records.size >= SleepRecordRepository::FEED_LIST_LIMIT
    end

    missing_records = correct_records.reject { |r| existing_ids.include?(r.id) }
    missing_records.each do |record|
      fanout_repo.add_to_feed(user_id: user_id, sleep_record: record)
    end

    # Success: release lock
    $redis.del(lock_key)
  rescue => e
    Rails.logger.error("[RepairSleepRecordFanoutJob] Failed for user #{user_id}: #{e.message}")
  end
end
