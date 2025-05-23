require 'rails_helper'

RSpec.describe Follow, type: :model do
  it "is valid with follower and followed" do
    follower = User.create!(name: "Alice")
    followed = User.create!(name: "Bob")
    follow = Follow.new(follower: follower, followed: followed)
    expect(follow).to be_valid
  end

  it "is invalid without follower" do
    followed = User.create!(name: "Bob")
    follow = Follow.new(followed: followed)
    expect(follow).not_to be_valid
  end

  it "is invalid without followed" do
    follower = User.create!(name: "Alice")
    follow = Follow.new(follower: follower)
    expect(follow).not_to be_valid
  end

  it "does not allow duplicate follows" do
    follower = User.create!(name: "Alice")
    followed = User.create!(name: "Bob")
    Follow.create!(follower: follower, followed: followed)
    duplicate = Follow.new(follower: follower, followed: followed)
    expect(duplicate).not_to be_valid
  end

  it "can follow and unfollow another user" do
    alice = User.create!(name: "Alice")
    bob = User.create!(name: "Bob")
    follow = alice.active_follows.create!(followed: bob)
    expect(alice.following).to include(bob)
    follow.destroy
    expect(alice.following).not_to include(bob)
  end

  it "cannot follow the same user twice" do
    alice = User.create!(name: "Alice")
    bob = User.create!(name: "Bob")
    alice.active_follows.create!(followed: bob)
    duplicate = alice.active_follows.build(followed: bob)
    expect(duplicate).not_to be_valid
  end

  it "cannot follow itself" do
    alice = User.create!(name: "Alice")
    follow = alice.active_follows.build(followed: alice)
    expect(follow).not_to be_valid
  end

  it "unfollowing when not following does nothing" do
    alice = User.create!(name: "Alice")
    bob = User.create!(name: "Bob")
    follow = alice.active_follows.find_by(followed: bob)
    expect(follow).to be_nil
    # Should not raise error
    expect { follow&.destroy }.not_to raise_error
  end
end
