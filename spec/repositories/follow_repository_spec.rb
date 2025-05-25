require 'rails_helper'

RSpec.describe FollowRepository do
  let(:repo) { FollowRepository.new }
  let(:follower) { User.create!(name: "Follower") }
  let(:followee) { User.create!(name: "Followee") }

  describe "#create" do
    it "creates a valid follow" do
      follow = repo.create(follower: follower, followee: followee)
      expect(follow).to be_persisted
      expect(follow.follower).to eq(follower)
      expect(follow.followee).to eq(followee)
    end

    it "returns invalid follow if duplicate exists" do
      repo.create(follower: follower, followee: followee)
      duplicate = repo.create(follower: follower, followee: followee)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:followee_id]).to include("has already been taken")
    end

    it "returns invalid follow if follower tries to follow self" do
      follow = repo.create(follower: follower, followee: follower)
      expect(follow).not_to be_valid
      expect(follow.errors[:follower_id]).to include("can't follow yourself")
    end
  end

  describe "#exists?" do
    it "returns true if follow exists" do
      repo.create(follower: follower, followee: followee)
      expect(repo.exists?(follower: follower, followee: followee)).to be true
    end

    it "returns false if follow does not exist" do
      expect(repo.exists?(follower: follower, followee: followee)).to be false
    end
  end

  describe "#find_by_follower_and_followee" do
    it "returns the follow if found" do
      created = repo.create(follower: follower, followee: followee)
      found = repo.find_by_follower_and_followee(follower: follower, followee: followee)
      expect(found).to eq(created)
    end

    it "returns nil if follow not found" do
      expect(repo.find_by_follower_and_followee(follower: follower, followee: followee)).to be_nil
    end
  end

  describe "#list_followee_ids" do
    it "returns list of followee ids for a follower" do
      other_user = User.create!(name: "Other")
      repo.create(follower: follower, followee: followee)
      repo.create(follower: follower, followee: other_user)
      expect(repo.list_followee_ids(user_id: follower.id)).to match_array([followee.id, other_user.id])
    end

    it "returns empty array if follower has no followees" do
      expect(repo.list_followee_ids(user_id: follower.id)).to eq([])
    end
  end
end
