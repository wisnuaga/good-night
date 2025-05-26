require "ostruct"

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
        # TODO: Move to background job
        sleep_record_repository.fanout_to_followers(sleep_record: session, follower_ids: follower_ids)

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

    attr_reader :clock_out, :follower_ids

    def validate_active_session!
      raise UsecaseError::ActiveSleepSessionNotFound if session.nil?
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
