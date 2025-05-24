require "ostruct"

module SleepRecordUsecase
  class Base
    def initialize(user)
      @user = user
    end

    private

    attr_reader :user

    def get_active_session
      @user.sleep_records.where(clock_out: nil).order(:clock_in).last
    end

    def success(record)
      OpenStruct.new(success?: true, data: record)
    end

    def failure(error_message)
      OpenStruct.new(success?: false, error: error_message)
    end
  end
end
