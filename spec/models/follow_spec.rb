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
end