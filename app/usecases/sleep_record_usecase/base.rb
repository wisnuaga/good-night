require "ostruct"

module SleepRecordUsecase
  class Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new)
      @user = user
      @sleep_record_repository = sleep_record_repository
    end

    private

    attr_reader :user, :sleep_record_repository, :session

    def validate_user!
      raise UsecaseError::UserNotFoundError unless user
    end

    def active_session
      sleep_record_repository.find_active_by_user(user_id: user.id)
    end

    def session
      @session ||= active_session
    end

    def success(record)
      OpenStruct.new(success?: true, data: record)
    end

    def failure(error_message)
      OpenStruct.new(success?: false, error: error_message)
    end
  end
end
