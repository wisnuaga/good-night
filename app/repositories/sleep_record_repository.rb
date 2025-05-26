class SleepRecordRepository
  FEED_LIST_LIMIT = (ENV['FEED_LIST_LIMIT'] || 50).to_i
  FEED_TTL_SECONDS = (ENV['FEED_TTL_SECONDS'] || 604_800).to_i  # 7 days

  # Use a method so that the cutoff is always relative to current time
  def feed_since_limit
    FEED_TTL_SECONDS.seconds.ago
  end

  def list_by_user_ids(user_ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
                       .where('clock_in >= ?', feed_since_limit)
                       .where.not(clock_out: nil)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
  end

  def list_by_ids(ids:, limit: FEED_LIST_LIMIT)
    SleepRecord.where(id: ids).order(clock_in: :desc).limit(limit)
  end

  def find_active_by_user(user_id:)
    SleepRecord.where(user_id: user_id, clock_out: nil)
               .order(clock_in: :desc)
               .first
  end

  # Create a new sleep record for a user
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

  # Fan out a sleep record to follower feeds in Redis sorted sets
  #
  # Stores records sorted by clock_in timestamp to support efficient feed retrieval.
  def write_fanout(sleep_record:, follower_ids:)
    follower_ids.each do |follower_id|
      add_to_feed(user_id: follower_id, sleep_record: sleep_record)
    end
  end

  # List cached sleep record IDs from Redis feed for a user
  def list_fanout(user_id:, cursor: nil, limit: FEED_LIST_LIMIT)
    key = feed_key(user_id: user_id)

    if cursor
      # Use ZREVRANGEBYSCORE to get items with score (clock_in) < cursor
      $redis.zrevrangebyscore(key, "(#{cursor}", "-inf", limit: [0, limit]).map(&:to_i)
    else
      $redis.zrevrange(key, 0, limit - 1).map(&:to_i)
    end
  end

  def add_to_feed(user_id:, sleep_record:)
    key = feed_key(user_id: user_id)

    # ZADD with NX only adds if not already present (idempotent)
    $redis.zadd(key, [sleep_record.clock_in.to_i, sleep_record.id], nx: true)
    trim_feed(user_id: user_id)
  end

  def trim_feed(user_id:)
    key = feed_key(user_id: user_id)
    $redis.zremrangebyrank(key, 0, -(FEED_LIST_LIMIT + 1))
    $redis.expire(key, FEED_TTL_SECONDS)
  end

  private

  def feed_key(user_id:)
    "feed:#{user_id}"
  end
end
