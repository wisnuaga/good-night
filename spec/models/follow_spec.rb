require 'rails_helper'

RSpec.describe Follow, type: :model do
  it "is valid with follower and followee" do
    follower = User.create!(name: "Alice")
    followee = User.create!(name: "Bob")
    follow = Follow.new(follower: follower, followee: followee)
    expect(follow).to be_valid
  end

  it "is invalid without follower" do
    followee = User.create!(name: "Bob")
    follow = Follow.new(followee: followee)
    expect(follow).not_to be_valid
    expect(follow.errors[:follower]).to include("must exist")
  end

  it "is invalid without followee" do
    follower = User.create!(name: "Alice")
    follow = Follow.new(follower: follower)
    expect(follow).not_to be_valid
    expect(follow.errors[:followee]).to include("must exist")
  end

  it "does not allow duplicate follows" do
    follower = User.create!(name: "Alice")
    followee = User.create!(name: "Bob")
    Follow.create!(follower: follower, followee: followee)
    duplicate = Follow.new(follower: follower, followee: followee)
    duplicate.valid?  # run validations before checking errors
    expect(duplicate.errors[:followee_id]).to include("has already been taken")
  end

  it "can follow and unfollow another user" do
    alice = User.create!(name: "Alice")
    bob = User.create!(name: "Bob")
    follow = alice.active_follows.create!(followee: bob)
    expect(alice.following).to include(bob)
    follow.destroy
    expect(alice.following).not_to include(bob)
  end

  it "cannot follow the same user twice" do
    alice = User.create!(name: "Alice")
    bob = User.create!(name: "Bob")
    alice.active_follows.create!(followee: bob)
    duplicate = alice.active_follows.build(followee: bob)
    expect(duplicate).not_to be_valid
  end

  it "cannot follow itself" do
    alice = User.create!(name: "Alice")
    follow = alice.active_follows.build(followee: alice)
    follow.valid? # run validations
    expect(follow.errors[:follower_id]).to include("can't follow yourself")
  end

  it "unfollowing when not following does nothing" do
    alice = User.create!(name: "Alice")
    bob = User.create!(name: "Bob")
    follow = alice.active_follows.find_by(followee: bob)
    expect(follow).to be_nil
    expect { follow&.destroy }.not_to raise_error
  end
end
