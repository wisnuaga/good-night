module SleepRecordUsecase
  class ClockOut < Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, follow_repository: FollowRepository.new, clock_out: Time.current)
      super(user, sleep_record_repository: sleep_record_repository, follow_repository: follow_repository)
      @clock_out = clock_out
    end

    def call
      validate_user!
      validate_active_session!

      session.clock_out = clock_out

      if session.save
        if follower_ids.count <= Repository::FANOUT_LIMIT
          SleepRecordFanoutJob.perform_later(session.id, follower_ids)
        else
          Rails.logger.info("[SleepRecordUsecase::ClockOut] Skipping fanout for user #{user.id} due to follower count (#{follower_ids.count}) exceeding limit #{Repository::FANOUT_LIMIT}. Will fanout on read.")
        end

        success(session)
      else
        failure("Failed to clock out")
      end
    rescue UsecaseError::UserNotFoundError, UsecaseError::ActiveSleepSessionNotFound => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    attr_reader :clock_out

    def validate_active_session!
      raise UsecaseError::ActiveSleepSessionNotFound if session.nil?
    end

    def fetch_follower_ids
      ids = follow_repository.list_follower_ids(user_id: user.id, limit: Repository::FANOUT_LIMIT + 1) # FANOUT_LIMIT + 1 to handle exceed the limit checking
      (ids + [user.id]).uniq
    end

    def follower_ids
      @follower_ids ||= fetch_follower_ids
    end
  end
end
