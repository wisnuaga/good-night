require "ostruct"

module SleepRecordUsecase
  class ClockOut < Base
    attr_reader :user, :sleep_record
    def initialize(user)
      super(user)
    end

    def call
      validate

      return failure("No active sleep session found") if active_session.nil?

      active_session.clock_out = Time.current

      if active_session.save
        self.success(active_session)
      else
        self.failure("Failed to clock out")
      end
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end
  end
end
