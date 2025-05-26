class SleepRecordRepository
  FEED_LIST_LIMIT = (ENV['FEED_LIST_LIMIT'] || 50).to_i
  FEED_TTL_SECONDS = (ENV['FEED_TTL_SECONDS'] || 604_800).to_i  # 7 days

  def list_by_user_ids(user_ids, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
  end

  def fanout_to_followers(sleep_record_id:, follower_ids:)
    follower_ids.each do |follower_id|
      key = feed_key(user_id: follower_id)
      $redis.lpush(key, sleep_record_id)
      $redis.ltrim(key, 0, FEED_LIST_LIMIT - 1)
      $redis.expire(key, FEED_TTL_SECONDS)
    end
  end

  def list_fanout(user_id:, cursor: nil, limit: FEED_LIST_LIMIT)
    key = feed_key(user_id: user_id)
    ids = $redis.lrange(key, 0, limit - 1).map(&:to_i)
    return [] if ids.empty?

    # Fetch records preserving Redis order
    records = SleepRecord.where(id: ids).index_by(&:id)
    records_in_order = ids.map { |id| records[id] }.compact

    # Filter by cursor if provided (optional, depending on your strategy)
    if cursor
      records_in_order = records_in_order.select { |r| r.clock_in < cursor }
    end

    records_in_order.take(limit)
  end

  def rebuild_feed_cache(user_id:, user_ids:)
    key = feed_key(user_id: user_id)
    # Fetch latest feed IDs from DB (cursor: nil to get newest)
    records = list_by_user_ids(user_ids, cursor: nil, limit: FEED_LIST_LIMIT)
    record_ids = records.map(&:id)
    $redis.del(key)
    $redis.lpush(key, record_ids.reverse) unless record_ids.empty?  # LPUSH order reversed for correct order
    $redis.expire(key, FEED_TTL_SECONDS)
  end

  private

  def feed_key(user_id:)
    "feed:#{user_id}"
  end
end
