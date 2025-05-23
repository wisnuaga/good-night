require 'rails_helper'

RSpec.describe User, type: :model do
  it "is valid with a name" do
    user = User.new(name: "Alice")
    expect(user).to be_valid
  end

  it "is invalid without a name" do
    user = User.new(name: nil)
    expect(user).not_to be_valid
  end

  it "can follow and unfollow another user" do
    alice = User.create!(name: "Alice")
    bob = User.create!(name: "Bob")
    follow = alice.active_follows.create!(followed: bob)
    expect(alice.following).to include(bob)
    follow.destroy
    expect(alice.following).not_to include(bob)
  end
end