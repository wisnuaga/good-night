class Follow < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :followee, class_name: "User"

  validates :followee_id, uniqueness: { scope: :follower_id }
  validate :cannot_follow_self

  private

  def cannot_follow_self
    if follower_id == followee_id
      errors.add(:follower_id, "can't follow yourself")
    end
  end
end
