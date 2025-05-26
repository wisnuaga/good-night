class SleepRecordRepository
  FEED_LIST_LIMIT = (ENV['FEED_LIST_LIMIT'] || 50).to_i
  FEED_TTL_SECONDS = (ENV['FEED_TTL_SECONDS'] || 604_800).to_i  # 7 days

  # Use a method so that the cutoff is always relative to current time
  def feed_since_limit
    FEED_TTL_SECONDS.seconds.ago
  end

  # List sleep records for given user_ids, only within the cutoff window,
  # optionally paginate by cursor (clock_in timestamp)
  #
  # INDEXES:
  # - Should be supported by a partial composite index on (user_id, clock_in)
  #   with WHERE clock_out IS NOT NULL to optimize filtering and ordering.
  #   This index allows Postgres to efficiently filter and order by clock_in DESC,
  #   scanning only records with clock_out NOT NULL for the specified user_ids and clock_in range.
  #
  # QUERY DETAILS:
  # - Filters:
  #   user_id IN user_ids
  #   clock_in >= feed_since_limit (cutoff)
  #   clock_out IS NOT NULL (finished sessions)
  #   clock_in < cursor (pagination cursor, optional)
  # - Ordering: clock_in DESC
  #
  # PostgreSQL uses the partial index to scan relevant rows in index order,
  # making sorting efficient and limiting unnecessary row scans.
  def list_by_user_ids(user_ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
                       .where('clock_in >= ?', feed_since_limit)
                       .where.not(clock_out: nil)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
  end

  # List sleep records by specific IDs with cutoff and cursor pagination.
  #
  # NOTE:
  # - No composite index combining id and clock_in, so this query
  #   may not be as efficient for large ID sets because filtering by clock_in and clock_out
  #   could cause sequential scans.
  # - Relies primarily on primary key index (id).
  #
  # RECOMMENDATION:
  # - Keep the limit small (default 50).
  # - Consider adding composite indexes if this query becomes a bottleneck.
  def list_by_ids(ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(id: ids)
                       .where('clock_in >= ?', feed_since_limit)
                       .where.not(clock_out: nil)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
  end

  # Count how many records exist for given user_ids within cutoff,
  # only counting finished sessions (clock_out IS NOT NULL).
  #
  # INDEXES:
  # - Uses the same partial composite index on (user_id, clock_in)
  #   WHERE clock_out IS NOT NULL for efficient counting.
  def count_by_user_ids(user_ids:)
    total = SleepRecord.where(user_id: user_ids)
                       .where('clock_in >= ?', feed_since_limit)
                       .where.not(clock_out: nil)
                       .count

    [total, FEED_LIST_LIMIT].min
  end

  # Find the currently active (no clock_out) sleep record for a user.
  #
  # INDEXES:
  # - Partial composite index on (user_id, clock_in) WHERE clock_out IS NULL
  #   supports efficient lookups of active sessions.
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
