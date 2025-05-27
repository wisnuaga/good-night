module FollowUsecase
  class Unfollow < Base
    def call
      validate

      follow = follow_repository.find_by_follower_and_followee(follower: user, followee: followee)
      return failure("Not following this user") unless follow

      if follow.destroy!
        # Schedule fanout removal job after 1 hour
        RemoveFanoutAfterUnfollowJob.set(wait: 1.hour).perform_later(user.id, followee.id)
        success({ message: "Unfollowed user successfully" })
      else
        failure("Failed to unfollow user")
      end
    rescue UsecaseError::UserNotFoundError => e
      failure(e.message)
    rescue => e
      failure("Unexpected error: #{e.message}")
    end

    private

    def remove_feeds
      feeds_id
    end
  end
end
