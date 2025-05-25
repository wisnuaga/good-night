module SleepRecordUsecase
  class List < Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, include_followees: false)
      super(user, sleep_record_repository: sleep_record_repository)
      @include_followees = include_followees
    end

    def call
      validate

      sleep_records = @sleep_record_repository.list_by_user_ids(user_ids)

      success({ data: sleep_records })
      # TODO: add pagination
    end

    private

    def user_ids
      return [ @user.id ] unless @include_followees

      followee_ids = @user.active_follows.pluck(:followee_id)
      followee_ids << @user.id
      followee_ids
    end
  end
end
