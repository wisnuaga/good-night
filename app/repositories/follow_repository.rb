class FollowRepository
  def create(follower:, followee:)
    Follow.create(follower: follower, followee: followee)
  end

  def exists?(follower:, followee:)
    Follow.exists?(follower: follower, followee: followee)
  end
end
