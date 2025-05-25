module FollowUsecase
  class Follow < Base
    def call
      validate

      if follow_repository.exists?(follower: user, followee: followee)
        return failure("Already following this user")
      end

      follow = follow_repository.create(follower: user, followee: followee)
      if follow.persisted?
        success({ message: "Followed user successfully" })
      else
        failure(follow.errors.full_messages.join(", "))
      end
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end
  end
end
