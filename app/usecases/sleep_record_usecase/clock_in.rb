require "ostruct"

module SleepRecordUsecase
  class ClockIn < SleepRecordUsecase::Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, clock_in: Time.current)
      super(user, sleep_record_repository: sleep_record_repository)
      @clock_in = clock_in
    end

    def call
      validate

      record = sleep_record_repository.create(
        user_id: user.id,
        clock_in: @clock_in,
      )

      if record.persisted?
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

    def validate
      super
      session = active_session
      raise UsecaseError::ActiveSleepSessionAlreadyExists if session&.persisted?
    end
  end
end
