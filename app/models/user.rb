class User < ApplicationRecord
  # users I follow
  has_many :active_follows, class_name: "Follower", foreign_key: "follower_id", dependent: :destroy
  has_many :following, through: :active_follows, source: :user

  # users who follow me
  has_many :passive_follows, class_name: "Follower", foreign_key: "user_id", dependent: :destroy
  has_many :followers, through: :passive_follows, source: :follower
end
