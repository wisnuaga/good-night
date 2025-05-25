class SleepRecordRepository
  def list_by_user_ids(user_ids)
    SleepRecord.where(user_id: user_ids).order(clock_in: :desc)
  end

  def find_active_by_user(user_id:)
    SleepRecord.where(user_id: user_id, clock_out: nil).order(clock_in: :desc).first
  end

  def create(user_id:, clock_in:, clock_out: nil)
    sleep_record = SleepRecord.new(
      user_id: user_id,
      clock_in: clock_in,
      clock_out: clock_out
    )
    sleep_record.save ? sleep_record : nil
  end

  def delete(sleep_record)
    sleep_record.destroy
  end

  def fanout_to_followers(sleep_record, follower_ids)
    follower_ids.each do |follower_id|
      $redis.lpush(feed_key(follower_id), sleep_record.to_json)
      $redis.ltrim(feed_key(follower_id), 0, FEED_LIST_LIMIT - 1)
    end
  end

  private

  def feed_key(follower_id)
    "feed:#{follower_id}"
  end
end
