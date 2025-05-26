class FanoutRepository < Repository
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