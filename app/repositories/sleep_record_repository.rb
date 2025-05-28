class SleepRecordRepository < Repository


  def initialize
    @cache = Caches::SleepRecordCache.new
  end

  def list_by_user_ids(user_ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
                       .where('clock_in >= ?', feed_since_limit)
                       .where.not(sleep_time: nil)
    query = query.where('sleep_time < ?', cursor) if cursor
    query.order(sleep_time: :desc).limit(limit)
  end

  def count_by_user_ids(user_ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
                       .where('clock_in >= ?', feed_since_limit)
                       .where.not(sleep_time: nil)
    query = query.where('sleep_time < ?', cursor) if cursor
    total = query.order(sleep_time: :desc).count

    [ total, limit ].min
  end

  # Cache-aware list_by_ids
  def list_by_ids(ids:, limit: FEED_LIST_LIMIT)
    cached, missed_ids = @cache.get_many(ids)

    if missed_ids.any?
      from_db = SleepRecord.where(id: missed_ids)
      @cache.set_many(from_db)
      cached.concat(from_db)
    end

    # Ensure order by given ID list and limit
    sorted = ids.map { |id| cached.find { |rec| rec.id == id } }.compact
    sorted.take(limit)
  end

  def find_active_by_user(user_id)
    SleepRecord.where(user_id: user_id, clock_out: nil).first # Expected only one record, because overlapping will be done by SleepRecord.no_overlapping_active_sessions validation
  end

  def find_by_id(id)
    SleepRecord.find_by(id: id)
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
end
