module SleepRecordUsecase
  class ClockIn < Base
    FANOUT_LIMIT = (ENV['SLEEP_RECORD_FANOUT_LIMIT'] || 1000).to_i

    def initialize(user, sleep_record_repository: SleepRecordRepository.new, follow_repository: FollowRepository.new, clock_in: Time.current)
      super(user, sleep_record_repository: sleep_record_repository, follow_repository: follow_repository)
      @clock_in = clock_in
    end

    def call
      validate_user!
      validate_no_active_session!

      record = sleep_record_repository.create(
        user_id: user.id,
        clock_in: clock_in,
        )

      if record.persisted?
        follower_ids = fetch_follower_ids

        if follower_ids.count <= FANOUT_LIMIT
          SleepRecordFanoutJob.perform_later(record.id, follower_ids)
        else
          Rails.logger.info("[SleepRecordUsecase::ClockIn] Skipping fanout for user #{user.id} due to follower count (#{follower_ids.count}) exceeding limit #{FANOUT_LIMIT}. Will fanout on read.")
        end

        success(record)
      else
        failure(record.errors.full_messages.join(", "))
      end
    rescue UsecaseError::UserNotFoundError, UsecaseError::ActiveSleepSessionAlreadyExists => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    attr_reader :clock_in, :follower_ids

    def validate_no_active_session!
      raise UsecaseError::ActiveSleepSessionAlreadyExists if session&.persisted?
    end

    def fetch_follower_ids
      ids = follow_repository.list_follower_ids(user_id: user.id)
      (ids + [user.id]).uniq
    end

    def follower_ids
      @follower_ids ||= fetch_follower_ids
    end
  end
end
