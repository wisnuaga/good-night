require "ostruct"

module SleepRecordUsecase
  class Base
    def initialize(user, sleep_record_repository: SleepRecordRepository.new)
      @user = user
      @sleep_record_repository = sleep_record_repository
    end

    private

    attr_reader :user, :sleep_record_repository

    def validate
      raise UsecaseError::UserNotFoundError unless @user
    end

    def active_session
      sleep_record_repository.find_active_by_user(user: @user.id)
    end

    def success(record)
      OpenStruct.new(success?: true, data: record)
    end

    def failure(error_message)
      OpenStruct.new(success?: false, error: error_message)
    end
  end
end
