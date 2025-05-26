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
      return success({ data: [], next_cursor: nil }) if record_ids.empty?

      cursor_id = Pagination::CursorHelper.decode_cursor(cursor)
      filtered_ids = cursor_id ? record_ids.select { |id| id < cursor_id } : record_ids
      limited_ids = filtered_ids.take(limit)

      records = sleep_record_repository.find_by_ids(limited_ids)

      # Detect and log missing_ids
      returned_ids = records.map(&:id)
      missing_ids = limited_ids - returned_ids
      Rails.logger.info("[SleepRecord] Missing IDs for user #{user.id}: #{missing_ids.inspect}") unless missing_ids.empty?

      # Prepare next cursor
      last_id = limited_ids.last
      next_cursor = filtered_ids.length > limit ? Pagination::CursorHelper.encode_cursor(last_id) : nil

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
