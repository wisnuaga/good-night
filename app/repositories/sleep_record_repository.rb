class SleepRecordRepository
  FEED_LIST_LIMIT = (ENV['FEED_LIST_LIMIT'] || 50).to_i
  FEED_TTL_SECONDS = (ENV['FEED_TTL_SECONDS'] || 604800).to_i  # default 7 days

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

  def fanout_to_followers(sleep_record:, follower_ids:)
    follower_ids.each do |follower_id|
      key = feed_key(user_id: follower_id)
      $redis.lpush(key, sleep_record.id)
      $redis.ltrim(key, 0, FEED_LIST_LIMIT - 1)
      $redis.expire(key, FEED_TTL_SECONDS)
    end
  end

  def list_fanout(user_id:)
    key = feed_key(user_id: user_id)
    ids = $redis.lrange(key, 0, FEED_LIST_LIMIT - 1).map(&:to_i)
    return [] if ids.empty?

    # Batch fetch sleep records ordered by ids as per Redis order
    records = SleepRecord.where(id: ids).index_by(&:id)
    # Return records in Redis list order
    ids.map { |id| records[id] }.compact
  end

  private

  def feed_key(user_id:)
    "feed:#{user_id}"
  end
end
