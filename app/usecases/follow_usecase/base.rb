require "ostruct"

module FollowUsecase
  class UserNotFoundError < StandardError; end
  class FolloweeNotFoundError < UserNotFoundError; end
  class FollowerNotFoundError < UserNotFoundError; end

  class Base
    def initialize(user, followee_id, follow_repository: FollowRepository.new)
      @user = user
      @followee_id = followee_id
      @follow_repository = follow_repository
    end

    private

    attr_reader :user, :followee_id, :follow_repository

    def followee
      @followee ||= User.find_by(id: followee_id)
    end

    # Returns OpenStruct success or failure, no exceptions
    def validate
      raise FollowUsecase::FollowerNotFoundError, "User not found" unless user
      raise FollowUsecase::FolloweeNotFoundError, "Followed user not found" unless followee
    end

    def success(record)
      OpenStruct.new(success?: true, data: record)
    end

    def failure(error_message)
      OpenStruct.new(success?: false, error: error_message)
    end
  end
end
