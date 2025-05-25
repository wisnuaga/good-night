module FollowUsecase
  class Unfollow < Base
    def call
      validate

      follow = follow_repository.find_existing(follower: user, followee: followee)
      return failure("Not following this user") unless follow

      if follow.destroy!
        success({ message: "Unfollowed user successfully" })
      else
        failure("Failed to unfollow user")
      end
    rescue FollowUsecase::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end
  end
end
