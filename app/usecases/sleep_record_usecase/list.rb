module SleepRecordUsecase
  class List < Base
    def initialize(user, include_followers: false)
      super(user)
      @include_followers = include_followers
    end

    def call
      return failure("User not found") unless @user

      follower_ids = get_follower_ids
      sleep_records = SleepRecord.where(user_id: follower_ids).order(clock_in: :desc)

      success(sleep_records)
    end

    private

    def get_follower_ids
      return [ @user.id ] unless @include_followers

      follower_ids = @user.active_follows.pluck(:followed_id)
      follower_ids << @user.id
      follower_ids
    end
  end
end
