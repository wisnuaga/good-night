class FollowRepository
  def create(follower:, followee:)
    Follow.create(follower: follower, followee: followee)
  end

  def exists?(follower:, followee:)
    Follow.exists?(follower: follower, followee: followee)
  end

  def find_by_follower_and_followee(follower:, followee:)
    Follow.find_by(follower: follower, followee: followee)
  end

  def list_followee_ids(follower_id:)
    Follow.where(follower_id: follower_id).pluck(:followee_id)
  end
end
