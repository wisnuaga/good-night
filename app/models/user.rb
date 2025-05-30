class User < ApplicationRecord
  validates :name, presence: true

  # Users I follow
  has_many :active_follows, class_name: "Follow", foreign_key: "follower_id", dependent: :destroy
  has_many :following, through: :active_follows, source: :followee

  # Users who follow me
  has_many :passive_follows, class_name: "Follow", foreign_key: "followee_id", dependent: :destroy
  has_many :followers, through: :passive_follows, source: :follower

  has_many :sleep_records, dependent: :destroy
end
