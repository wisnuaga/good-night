class FanoutRepository < Repository
  # Fan out a sleep record to follower feeds in Redis sorted sets
  # Stores records sorted by sleep_time (duration in seconds)
  def write_fanout(sleep_record:, follower_ids:)
    follower_ids.each do |follower_id|
      add_to_feed(user_id: follower_id, sleep_record: sleep_record)
    end
  end

  # List cached sleep record IDs from Redis feed for a user
  # Pagination uses sleep_time as the score cursor
  def list_fanout(user_id:, cursor: nil, limit: FEED_LIST_LIMIT)
    key = feed_key(user_id)

    if cursor
      # Get items with score (sleep_time) less than cursor, descending order
      $redis.zrevrangebyscore(key, "(#{cursor}", "-inf", limit: [0, limit]).map(&:to_i)
    else
      # Get top N items by sleep_time descending
      $redis.zrevrange(key, 0, limit - 1).map(&:to_i)
    end
  end

  # Remove specific sleep record IDs from a user's feed
  def remove_from_feed(user_id:, sleep_record_ids:)
    key = feed_key(user_id)
    # Ensure all values are strings (Redis stores as strings)

    sleep_record_ids.each do |id|
      $redis.zrem(key, id)
    end
  end

  def add_to_feed(user_id:, sleep_record:)
    key = feed_key(user_id)

    # Use sleep_time as score; fallback to 0 if nil
    score = sleep_record.sleep_time || 0

    # Add to sorted set, NX to avoid duplicates
    $redis.zadd(key, [score, sleep_record.id], nx: true)
    trim_feed(user_id)
  end

  def trim_feed(user_id)
    key = feed_key(user_id)
    # Keep only the top FEED_LIST_LIMIT items, remove older ones
    $redis.zremrangebyrank(key, 0, -(FEED_LIST_LIMIT + 1))
    $redis.expire(key, FEED_TTL_SECONDS)
  end

  private

  def feed_key(user_id)
    "feed:#{user_id}"
  end
end
