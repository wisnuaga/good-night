module SleepRecordUsecase
  class Base < Usecase
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, follow_repository: FollowRepository.new)
      @user = user
      @sleep_record_repository = sleep_record_repository
      @follow_repository = follow_repository
    end

    private

    attr_reader :user, :sleep_record_repository, :follow_repository, :session

    def validate_user!
      raise UsecaseError::UserNotFoundError unless user
    end

    def active_session
      sleep_record_repository.find_active_by_user(user_id: user.id)
    end

    def session
      @session ||= active_session
    end
  end
end
