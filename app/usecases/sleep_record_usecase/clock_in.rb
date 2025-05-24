require "ostruct"

module SleepRecordUsecase
  class ClockIn
    def initialize(user)
      @user = user
    end

    def call
      return failure("User not found") unless @user

      active_session = @user.sleep_records.where(clock_out: nil).last
      return failure("You already have an active sleep session") if active_session

      record = @user.sleep_records.new(clock_in: Time.current)

      if record.save
        success(record)
      else
        failure("Failed to create sleep record")
      end
    end

    private

    def success(record)
      OpenStruct.new(success?: true, sleep_record: record)
    end

    def failure(error_message)
      OpenStruct.new(success?: false, error: error_message)
    end
  end
end
