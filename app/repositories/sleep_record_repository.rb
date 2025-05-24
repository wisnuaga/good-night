class SleepRecordRepository
  def list(user_ids)
    SleepRecord.where(user_id: user_ids).order(clock_in: :desc)
  end

  def find(id)
    SleepRecord.find_by(id: id)
  end

  def find_active_by_user(user_id)
    SleepRecord.where(user_id: user_id, clock_out: nil).order(:clock_in).last
  end

  def create(user_id:, clock_in:, clock_out: nil)
    sleep_record = SleepRecord.new(
      user_id: user_id,
      clock_in: clock_in,
      clock_out: clock_out
    )
    sleep_record.save ? sleep_record : nil
  end

  def update(id:, clock_in: nil, clock_out: nil)
    sleep_record = SleepRecord.find_by(id: id)
    return nil unless sleep_record

    sleep_record.clock_in = clock_in if clock_in
    sleep_record.clock_out = clock_out if clock_out
    sleep_record.save ? sleep_record : nil
  end

  def delete(sleep_record)
    sleep_record.destroy
  end
end
