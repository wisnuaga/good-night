module SleepRecordUsecase
  class List < Base
    MIN_THRESHOLD = (ENV['SLEEP_RECORD_MIN_THRESHOLD'] || 3).to_i
    FRACTION = (ENV['SLEEP_RECORD_MISSING_FRACTION'] || 0.2).to_f

    def call(limit:, cursor: nil)
      validate_user!

      decoded_cursor = Pagination::CursorHelper.decode_cursor(cursor)
      cursor_time = decoded_cursor&.to_i

      record_ids = fanout_repository.list_fanout(user_id: user.id, cursor: cursor_time, limit: limit)
      if record_ids.empty?
        # Cache miss: fallback to DB query
        records = sleep_record_repository.list_by_user_ids(user_ids: followee_ids, cursor: cursor_time, limit: limit)

        if records.any?
          Rails.logger.info("[SleepRecord] Fallback DB fetch for user #{user.id} with #{records.size} records")
          Rails.logger.info("[SleepRecord] Repairing empty cache...")

          RepairSleepRecordFanoutJob.perform_later(user.id)
        end
      else
        records = sleep_record_repository.list_by_ids(ids: record_ids)
        total_records = sleep_record_repository.count_by_user_ids(user_ids: followee_ids, cursor: cursor_time, limit: limit)
        missing_count = total_records - record_ids.count

        # Log only if we expected to find these records (i.e., cache is non-empty)
        if missing_count >= missing_threshold(total_records)
          Rails.logger.info("[SleepRecord] Stale cache for user #{user.id}, missing #{missing_count} records — scheduling background rebuild")

          RepairSleepRecordFanoutJob.perform_later(user.id)
        end
      end

      last_clock_in = records.last&.clock_in
      next_cursor = records.length == limit && last_clock_in ? Pagination::CursorHelper.encode_cursor(last_clock_in.to_i) : nil

      success({ data: records, next_cursor: next_cursor })
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    attr_reader :followee_ids

    def fetch_followee_ids
      ids = follow_repository.list_followee_ids(user_id: user.id) # Limit by repository layer to avoid large records
      (ids + [user.id]).uniq
    end

    def followee_ids
      @followee_ids ||= fetch_followee_ids
    end

    def missing_threshold(total)
      [MIN_THRESHOLD, (total * FRACTION).ceil].max
    end
  end
end
