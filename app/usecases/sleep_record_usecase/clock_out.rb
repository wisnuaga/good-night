require "ostruct"

module SleepRecordUsecase
  class ClockOut < Base
    attr_reader :user, :sleep_record
    def initialize(user)
      super(user)
    end

    def call
      return failure("User not found") unless @user

      active_session = self.get_active_session
      return failure("No active sleep session found") if active_session.nil?

      active_session.clock_out = Time.current

      if active_session.save
        self.success(active_session)
      else
        self.failure("Failed to clock out")
      end
    end
  end
end
