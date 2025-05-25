require "ostruct"

module SleepRecordUsecase
  class ClockOut < Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, clock_out: Time.current)
      super(user, sleep_record_repository: sleep_record_repository)
      @clock_out = clock_out
    end

    def call
      validate_user!
      validate_active_session!

      session.clock_out = clock_out

      session.save ? success(session) : failure("Failed to clock out")
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
  end
end
