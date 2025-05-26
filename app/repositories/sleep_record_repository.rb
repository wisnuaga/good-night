class SleepRecordRepository < Repository
  def list_by_user_ids(user_ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
                       .where('clock_in >= ?', feed_since_limit)
                       .where.not(clock_out: nil)
    query = query.where('clock_in < ?', cursor) if cursor
    query.order(clock_in: :desc).limit(limit)
  end

  def count_by_user_ids(user_ids:, cursor: nil, limit: FEED_LIST_LIMIT)
    query = SleepRecord.where(user_id: user_ids)
                       .where('clock_in >= ?', feed_since_limit)
                       .where.not(clock_out: nil)
    query = query.where('clock_in < ?', cursor) if cursor
    total = query.order(clock_in: :desc).count

    [ total, limit ].min
  end

  def list_by_ids(ids:, limit: FEED_LIST_LIMIT)
    SleepRecord.where(id: ids).order(clock_in: :desc).limit(limit)
  end

  def find_active_by_user(user_id)
    SleepRecord.where(user_id: user_id, clock_out: nil)
               .order(clock_in: :desc)
               .first
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
