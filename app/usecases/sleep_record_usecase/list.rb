module SleepRecordUsecase
  class List < Base
    CURSOR_LIMIT = 20
    MISSING_THRESHOLD = 5
    DEFAULT_LIMIT = 10

    def call(cursor: nil, limit: CURSOR_LIMIT)
      validate_user!

      cursor_id = Pagination::CursorHelper.decode_cursor(cursor)

      record_ids = sleep_record_repository.list_fanout(user_id: user.id)
      filtered_ids = cursor_id ? record_ids.select { |id| id < cursor_id } : record_ids

      if record_ids.empty?
        # No cache fallback: fetch directly from DB
        records = sleep_record_repository.list_by_user_ids(user_ids: followee_ids, cursor: cursor, limit: limit)
        limited_ids = records.map(&:id)
        missing_ids = []

        if records.any?
          Rails.logger.info("[SleepRecord] Fallback DB fetch succeeded for user #{user.id} with #{records.size} records")
          # TODO: Trigger cache rebuild because cache was empty but DB has data
          Rails.logger.info("[SleepRecord] TODO: Trigger rebuild job for user #{user.id} (empty cache, fresh DB data)")
        end
      else
        limited_ids = filtered_ids.take(limit)
        records = sleep_record_repository.list_by_ids(ids: limited_ids)
        returned_ids = records.map(&:id)
        missing_ids = limited_ids - returned_ids

        unless missing_ids.empty?
          Rails.logger.info("[SleepRecord] Missing IDs for user #{user.id}: #{missing_ids.inspect}")
          if missing_ids.size >= MISSING_THRESHOLD
            # TODO: Trigger cache rebuild because cache was empty but DB has data
            Rails.logger.info("[SleepRecord] Triggered rebuild job for user #{user.id} due to missing IDs")
          end
        end
      end

      last_id = limited_ids.last
      next_cursor = filtered_ids.length > limit ? Pagination::CursorHelper.encode_cursor(last_id) : nil

      success({ data: records, next_cursor: next_cursor })
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    def followee_ids
      follow_ids = follow_repository.list_followee_ids(user_id: user.id)
      follow_ids << user.id
      follow_ids
    end
  end
end
