class SleepRecordRepository
  FEED_LIST_LIMIT = (ENV['FEED_LIST_LIMIT'] || 50).to_i
  FEED_TTL_SECONDS = (ENV['FEED_TTL_SECONDS'] || 604_800).to_i  # 7 days

  def list_by_user_ids(user_ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
  end

  def list_by_ids(ids:, cursor: nil, limit: FEED_TTL_SECONDS)
    query = SleepRecord.where(id: ids)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
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

  def fanout_to_followers(sleep_record_id:, follower_ids:)
    follower_ids.each do |follower_id|
      key = feed_key(user_id: follower_id)
      $redis.lpush(key, sleep_record_id)
      $redis.ltrim(key, 0, FEED_LIST_LIMIT - 1)
      $redis.expire(key, FEED_TTL_SECONDS)
    end
  end

  def list_fanout(user_id:)
    key = feed_key(user_id: user_id)
    $redis.lrange(key, 0, FEED_LIST_LIMIT - 1).map(&:to_i)
  end

  def rebuild_feed_cache(user_id:, user_ids:)
    key = feed_key(user_id: user_id)
    # Fetch latest feed IDs from DB (cursor: nil to get newest)
    records = list_by_user_ids(user_ids: user_ids, cursor: nil, limit: FEED_LIST_LIMIT)
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
