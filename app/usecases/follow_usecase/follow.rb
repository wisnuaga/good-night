module FollowUsecase
  class Follow < Base
    def call
      return failure("User not found") unless @user
      get_followee
      return failure("Followed user not found") unless @followee

      if @follow_repository.exists?(follower: @user, followee: @followee)
        return failure("Already following this user")
      end

      follow = @follow_repository.create(follower: @user, followee: @followee)
      if follow.persisted?
        success(follow)
      else
        failure(follow.errors.full_messages.join(", "))
      end
    end
  end
end
