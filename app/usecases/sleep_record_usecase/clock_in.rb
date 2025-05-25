require "ostruct"

module SleepRecordUsecase
  class ClockIn < Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, follow_repository: FollowRepository.new, clock_in: Time.current)
      super(user, sleep_record_repository: sleep_record_repository, follow_repository: follow_repository)
      @clock_in = clock_in
    end

    def call
      validate_user!
      validate_no_active_session!

      record = sleep_record_repository.create(
        user_id: user.id,
        clock_in: clock_in,
        )

      record.persisted? ? success(record) : failure(record.errors.full_messages.join(", "))
    rescue UsecaseError::UserNotFoundError, UsecaseError::ActiveSleepSessionAlreadyExists => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    attr_reader :clock_in

    def validate_no_active_session!
      raise UsecaseError::ActiveSleepSessionAlreadyExists if session&.persisted?
    end
  end
end
