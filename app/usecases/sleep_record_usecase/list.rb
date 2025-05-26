module SleepRecordUsecase
  class List < Base
    CURSOR_LIMIT = 20
    MISSING_THRESHOLD = 5

    def initialize(user, sleep_record_repository: SleepRecordRepository.new, follow_repository: FollowRepository.new, include_followees: false)
      super(user, sleep_record_repository: sleep_record_repository, follow_repository: follow_repository)
      @include_followees = include_followees
    end

    def call(cursor: nil, limit: CURSOR_LIMIT)
      validate_user!

      record_ids = sleep_record_repository.list_fanout(user_id: user.id)

      if record_ids.empty?
        # Cache miss — fallback to DB
        records = sleep_record_repository.list_by_user_ids(user_ids)
        # RebuildSleepRecordCacheJob.perform_async(user.id, user_ids)
        return success({ data: records, next_cursor: nil }) # You could add pagination later
      end

      # Step 2: Apply cursor pagination
      start_index = cursor ? record_ids.index(cursor.to_i)&.+(1) : 0
      paged_ids = record_ids.slice(start_index, limit) || []

      # Step 3: Fetch records by paged IDs from DB
      records_map = SleepRecord.where(id: paged_ids).index_by(&:id)
      records = paged_ids.map { |id| records_map[id] }.compact
      missing_ids = paged_ids - records_map.keys

      # Step 4: Trigger background job to rebuild if too many missing
      if missing_ids.size >= MISSING_THRESHOLD
        # RebuildSleepRecordCacheJob.perform_async(user.id, user_ids)
      end

      # Step 5: Build next cursor
      next_cursor = paged_ids[records.size]&.to_s

      success({ data: records, next_cursor: next_cursor })
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    attr_reader :include_followees

    def user_ids
      return [ user.id ] unless include_followees

      followee_ids = follow_repository.list_followee_ids(user_id: user.id)
      followee_ids << user.id
      followee_ids
    end
  end
end
