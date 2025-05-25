require "ostruct"

module SleepRecordUsecase
  class ClockOut < Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, clock_out: Time.current)
      super(user, sleep_record_repository: sleep_record_repository)
      @clock_out = clock_out
    end

    def call
      validate

      @session.clock_out = @clock_out

      if @session.save
        success(@session)
      else
        failure("Failed to clock out")
      end
    rescue UsecaseError::UserNotFoundError, UsecaseError::ActiveSleepSessionNotFound => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    def validate
      super
      @session = active_session
      raise UsecaseError::ActiveSleepSessionNotFound if @session.nil?
    end
  end
end
