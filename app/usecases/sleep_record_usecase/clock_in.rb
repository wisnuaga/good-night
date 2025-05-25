require "ostruct"

module SleepRecordUsecase
  class ClockIn < SleepRecordUsecase::Base
    def initialize(user)
      super(user)
    end

    def call
      validate

      return failure("You already have an active sleep session") if active_session

      record = @user.sleep_records.new(clock_in: Time.current)

      if record.save
        self.success(record)
      else
        self.failure("Failed to create sleep record")
      end
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end
  end
end
