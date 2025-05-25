require 'rails_helper'

RSpec.describe User, type: :model do
  it "is valid with a name" do
    user = User.new(name: "Alice")
    expect(user).to be_valid
  end

  it "is invalid without a name" do
    user = User.new(name: nil)
    expect(user).not_to be_valid
    expect(user.errors[:name]).to include("can't be blank")
  end

  describe "follower/following associations" do
    let(:alice) { User.create!(name: "Alice") }
    let(:bob) { User.create!(name: "Bob") }

    before do
      # alice follows bob
      alice.active_follows.create!(followee: bob)
    end

    it "allows a user to follow another user" do
      expect(alice.following).to include(bob)
    end

    it "shows followers of a user" do
      expect(bob.followers).to include(alice)
    end

    it "destroys follows when user is deleted" do
      expect { alice.destroy }.to change { Follow.count }.by(-1)
    end
  end
end
