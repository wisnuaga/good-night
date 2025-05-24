require "ostruct"

module SleepRecordUsecase
  class ClockIn < SleepRecordUsecase::Base
    attr_reader :user, :sleep_record
    def initialize(user)
      super(user)
    end

    def call
      return failure("User not found") unless @user

      active_session = self.get_active_session
      return failure("You already have an active sleep session") if active_session

      record = @user.sleep_records.new(clock_in: Time.current)

      if record.save
        self.success(record)
      else
        self.failure("Failed to create sleep record")
      end
    end
  end
end
