class RepairSleepRecordFanoutJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    lock_key = "repair_lock:#{user_id}"
    locked = $redis.set(lock_key, true, nx: true, ex: 60)
    return unless locked

    begin
      sleep_record_repo = SleepRecordRepository.new
      fanout_repo = FanoutRepository.new
      follow_repository = FollowRepository.new

      existing_ids = fanout_repo.list_fanout(user_id: user_id)

      first = true
      followee_cursor = nil
      followee_limit = 10
      sleep_time = 0.05

      loop do
        # TODO: Improvement -> this query not ordered by most longest sleep_time within last 7 days
        followee_ids, followee_cursor = follow_repository.list_followee_ids_batch(
          user_id: user_id,
          cursor: followee_cursor,
          limit: followee_limit
        )

        # Include self on first loop only
        if first
          followee_ids << user_id
          first = false
        end

        break if followee_ids.empty?

        correct_records = []
        cursor_time = nil
        loop do
          batch_records = sleep_record_repo.list_by_user_ids(
            user_ids: followee_ids,
            cursor: cursor_time
          )

          break if batch_records.empty?

          correct_records.concat(batch_records)
          correct_records.uniq!(&:id)
          cursor_time = batch_records.last&.sleep_time

          missing_records = correct_records.reject { |r| existing_ids.include?(r.id) }
          missing_records.each do |record|
            fanout_repo.add_to_feed(user_id: user_id, sleep_record: record)
          end

          break if cursor_time.nil?
          sleep(sleep_time)
        end

        break if followee_cursor.nil?
        sleep(sleep_time)
      end
    rescue => e
      Rails.logger.error("[RepairSleepRecordFanoutJob] Failed for user #{user_id}: #{e.message}")
    ensure
      $redis.del(lock_key)
    end
  end
end
