module SleepRecordUsecase
  class List < Base
    MIN_THRESHOLD = (ENV['SLEEP_RECORD_MIN_THRESHOLD'] || 3).to_i
    FRACTION = (ENV['SLEEP_RECORD_MISSING_FRACTION'] || 0.2).to_f

    def call(limit:, cursor: nil)
      validate_user!
      decoded_cursor = decode_cursor(cursor)

      record_ids = fanout_repository.list_fanout(user_id: user.id, cursor: decoded_cursor, limit: limit)
      records = record_ids.any? ? fetch_ordered_records(record_ids, decoded_cursor) : fetch_fallback_records(decoded_cursor, limit)

      next_cursor = generate_next_cursor(records, limit)

      success(data: records, next_cursor: next_cursor)
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    def decode_cursor(cursor)
      Pagination::CursorHelper.decode_cursor(cursor)
    end

    def fetch_ordered_records(record_ids, decoded_cursor)
      unsorted = sleep_record_repository.list_by_ids(ids: record_ids)
      record_map = unsorted.index_by(&:id)
      ordered = record_ids.map { |id| record_map[id] }.compact

      check_cache_staleness(record_ids, decoded_cursor)

      ordered
    end

    def fetch_fallback_records(decoded_cursor, limit)
      records = sleep_record_repository.list_by_user_ids(user_ids: followee_ids, cursor: decoded_cursor, limit: limit)

      if records.any?
        Rails.logger.info("[SleepRecord] Fallback DB fetch for user #{user.id} with #{records.size} records")
        Rails.logger.info("[SleepRecord] Repairing empty cache...")
        RepairSleepRecordFanoutJob.perform_later(user.id)
      end

      records
    end

    def check_cache_staleness(record_ids, decoded_cursor)
      total = sleep_record_repository.count_by_user_ids(user_ids: followee_ids, cursor: decoded_cursor)
      missing = total - record_ids.size

      return unless missing >= missing_threshold(total)

      Rails.logger.info("[SleepRecord] Stale cache for user #{user.id}, missing #{missing} records — scheduling background rebuild")
      RepairSleepRecordFanoutJob.perform_later(user.id)
    end

    def generate_next_cursor(records, limit)
      last_time = records.last&.sleep_time
      return nil unless records.length == limit && last_time

      Pagination::CursorHelper.encode_cursor(last_time.to_i)
    end

    def missing_threshold(total)
      [MIN_THRESHOLD, (total * FRACTION).ceil].max
    end

    def fetch_followee_ids
      ids = follow_repository.list_followee_ids(user_id: user.id)
      (ids + [user.id]).uniq
    end

    def followee_ids
      @followee_ids ||= fetch_followee_ids
    end
  end
end
