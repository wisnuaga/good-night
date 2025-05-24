module SleepRecordUsecase
  class List < Base
    def initialize(user, include_followees: false)
      super(user)
      @include_followees = include_followees
    end

    def call
      return failure("User not found") unless @user

      followee_ids = get_followee_ids
      sleep_records = SleepRecord.where(user_id: followee_ids).order(clock_in: :desc)

      success({ data: sleep_records })
      # TODO: add pagination
    end

    private

    def get_followee_ids
      return [ @user.id ] unless @include_followees

      followee_ids = @user.active_follows.pluck(:followee_id)
      followee_ids << @user.id
      followee_ids
    end
  end
end
