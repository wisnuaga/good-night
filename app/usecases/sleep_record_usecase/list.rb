module SleepRecordUsecase
  class List < Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, include_followees: false)
      super(user, sleep_record_repository: sleep_record_repository)
      @include_followees = include_followees
    end

    def call
      validate_user!

      sleep_records = sleep_record_repository.list_by_user_ids(user_ids)
      success({ data: sleep_records }) # TODO: add pagination
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    attr_reader :include_followees

    def user_ids
      return [ user.id ] unless include_followees

      user.active_follows.pluck(:followee_id).tap { |ids| ids << user.id }
    end
  end
end
