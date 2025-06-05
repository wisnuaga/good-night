class RemoveFanoutAfterUnfollowJob < ApplicationJob
  queue_as :default

  def perform(user_id, unfollowed_user_id)
    lock_key = "remove_lock:#{user_id}"
    locked = $redis.set(lock_key, true, nx: true, ex: 60)
    return unless locked

    begin
      user = UserRepository.new.find_by_id(user_id)
      followee = UserRepository.new.find_by_id(unfollowed_user_id)

      return unless followee && user

      # Confirm the user is *still* not following the target
      return if FollowRepository.new.exists?(follower: user, followee: followee)

      sleep_record_repo = SleepRecordRepository.new
      fanout_repo = FanoutRepository.new

      cursor_time = nil

      loop do
        records = sleep_record_repo.list_by_user_ids(
          user_ids: [unfollowed_user_id],
          cursor: cursor_time,
          limit: SleepRecordRepository::FEED_LIST_LIMIT
        )

        break if records.empty?

        record_ids = records.map(&:id)
        fanout_repo.remove_from_feed(user_id: user_id, sleep_record_ids: record_ids)

        # Move cursor to last record's sleep_time for next batch
        cursor_time = records.last&.sleep_time

        break if cursor_time.nil?
      end
    rescue => e
      Rails.logger.error("[RemoveFanoutAfterUnfollowJob] Failed for user #{user_id} unfollowed #{unfollowed_user_id}: #{e.message}")
      # Don't delete lock here; let ensure block handle it
    ensure
      $redis.del(lock_key)
    end
  end
end
