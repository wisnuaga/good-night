module FollowUsecase
  class Base < Usecase
    def initialize(user, followee_id, follow_repository: FollowRepository.new, user_repository: UserRepository.new)
      @user = user
      @followee_id = followee_id
      @follow_repository = follow_repository
      @user_repository = user_repository
    end

    private

    attr_reader :user, :followee_id, :follow_repository, :user_repository, :followee

    def followee
      @followee ||= user_repository.find_by_id(followee_id)
    end

    # Returns OpenStruct success or failure, no exceptions
    def validate
      raise UsecaseError::UserNotFoundError unless user
      raise UsecaseError::UserNotFoundError, "Followed user not found" unless followee
    end
  end
end
