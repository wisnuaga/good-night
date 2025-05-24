require "ostruct"

module FollowUsecase
  class Base
    def initialize(user)
      @user = user
    end

    private

    attr_reader :user

    def get_followed_user
      @followed_user ||= User.find_by(id: user.id)
    end

    def success(record)
      OpenStruct.new(success?: true, data: record)
    end

    def failure(error_message)
      OpenStruct.new(success?: false, error: error_message)
    end
  end
end
