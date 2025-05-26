class SleepRecordRepository
  FEED_LIST_LIMIT = (ENV['FEED_LIST_LIMIT'] || 50).to_i
  FEED_TTL_SECONDS = (ENV['FEED_TTL_SECONDS'] || 604_800).to_i  # 7 days

  # Use a method so that the cutoff is always relative to current time
  def feed_since_limit
    FEED_TTL_SECONDS.seconds.ago
  end

  # List sleep records for given user_ids, only within the cutoff window,
  # optionally paginate by cursor (clock_in timestamp)
  def list_by_user_ids(user_ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
                       .where('clock_in >= ?', feed_since_limit)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
  end

  # List sleep records by ids, with cutoff and cursor pagination
  def list_by_ids(ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(id: ids)
                       .where('clock_in >= ?', feed_since_limit)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
  end

  # Count how many records exist for given user_ids within cutoff
  def count_by_user_ids(user_ids:)
    SleepRecord.where(user_id: user_ids)
               .where('clock_in >= ?', feed_since_limit)
               .count
  end

  # Find the currently active (no clock_out) sleep record for a user
  def find_active_by_user(user_id:)
    SleepRecord.where(user_id: user_id, clock_out: nil)
               .order(clock_in: :desc)
               .first
  end

  # Create a new sleep record for user
  def create(user_id:, clock_in:, clock_out: nil)
    sleep_record = SleepRecord.new(
      user_id: user_id,
      clock_in: clock_in,
      clock_out: clock_out
    )
    sleep_record.save ? sleep_record : nil
  end

  # Delete a sleep record
  def delete(sleep_record)
    sleep_record.destroy
  end

  # Fan out a sleep record to follower feeds in Redis
  def fanout_to_followers(sleep_record:, follower_ids:)
    follower_ids.each do |follower_id|
      key = feed_key(user_id: follower_id)
      $redis.zadd(key, sleep_record.clock_in.to_i, sleep_record.id)
      $redis.zremrangebyrank(key, 0, -(FEED_LIST_LIMIT + 1)) # Keep most recent N
      $redis.expire(key, FEED_TTL_SECONDS)
    end
  end

  # List cached sleep record IDs from Redis feed for a user
  def list_fanout(user_id:, limit: FEED_LIST_LIMIT)
    key = feed_key(user_id: user_id)
    $redis.zrevrange(key, 0, limit - 1).map(&:to_i)
  end

  private

  def feed_key(user_id:)
    "feed:#{user_id}"
  end
end
