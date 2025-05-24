require "ostruct"

module FollowUsecase
  class Base
    def initialize(user, followee_id, follow_repository: FollowRepository.new)
      @user = user
      @followee_id = followee_id
      @follow_repository = follow_repository
    end

    private

    attr_reader :user

    def get_followee
      @followee ||= User.find_by(id: @followee_id)
    end

    def success(record)
      OpenStruct.new(success?: true, data: record)
    end

    def failure(error_message)
      OpenStruct.new(success?: false, error: error_message)
    end
  end
end
