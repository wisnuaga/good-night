class FollowRepository < Repository
  def create(follower:, followee:)
    Follow.create(follower: follower, followee: followee)
  end

  def exists?(follower:, followee:)
    Follow.exists?(follower: follower, followee: followee)
  end

  def find_by_follower_and_followee(follower:, followee:)
    Follow.find_by(follower: follower, followee: followee)
  end

  def list_followee_ids(user_id:, limit: FANOUT_LIMIT)
    Follow.where(follower_id: user_id).limit(limit).pluck(:followee_id)
  end

  def list_follower_ids(user_id:, limit: FANOUT_LIMIT)
    Follow.where(followee_id: user_id).limit(limit).pluck(:follower_id)
  end
end
