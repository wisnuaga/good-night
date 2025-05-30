module SleepRecordUsecase
  class Base < Usecase
    def initialize(user, sleep_record_repository: SleepRecordRepository.new, follow_repository: FollowRepository.new, fanout_repository: FanoutRepository.new)
      @user = user
      @sleep_record_repository = sleep_record_repository
      @follow_repository = follow_repository
      @fanout_repository = fanout_repository
    end

    private

    attr_reader :user, :sleep_record_repository, :follow_repository, :fanout_repository, :session

    def validate_user!
      raise UsecaseError::UserNotFoundError unless user
    end

    def active_session
      sleep_record_repository.find_active_by_user(user.id)
    end

    def session
      @session ||= active_session
    end

    def encode_cursor(id)
      Base64.urlsafe_encode64(id.to_s)
    end

    def decode_cursor(cursor)
      Base64.urlsafe_decode64(cursor).to_f
    rescue
      nil
    end
  end
end
