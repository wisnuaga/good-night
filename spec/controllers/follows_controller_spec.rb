require 'rails_helper'

RSpec.describe FollowsController, type: :controller do
  let!(:alice) { User.create!(name: "Alice") }
  let!(:bob)   { User.create!(name: "Bob") }

  before do
    request.headers["X-User-Id"] = alice.id.to_s
  end

  describe "PUT #follow" do
    it "follows another user" do
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:ok)
      expect(alice.following).to include(bob)
    end

    it "cannot follow self" do
      put :follow, params: { id: alice.id }
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to eq("Cannot follow yourself")
    end

    it "cannot follow the same user twice" do
      Follow.create!(follower: alice, followed: bob)
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include("Follower has already been taken")
    end

    it "returns error if user to follow not found" do
      put :follow, params: { id: 99999 }
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("User to follow not found")
    end
  end

  describe "PUT #unfollow" do
    it "unfollows a followed user" do
      Follow.create!(follower: alice, followed: bob)
      put :unfollow, params: { id: bob.id }
      expect(response).to have_http_status(:ok)
      expect(alice.following).not_to include(bob)
    end

    it "returns error if not following" do
      put :unfollow, params: { id: bob.id }
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Follow relation not found")
    end

    it "returns error if user to unfollow not found" do
      put :unfollow, params: { id: 99999 }
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("User to follow not found")
    end
  end

  describe "authentication" do
    it "returns unauthorized if X-User-Id header is missing" do
      request.headers["X-User-Id"] = nil
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("X-User-Id header missing")
    end

    it "returns unauthorized if X-User-Id is blank" do
      request.headers["X-User-Id"] = ""
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("X-User-Id header missing")
    end

    it "returns unauthorized if X-User-Id is not found" do
      request.headers["X-User-Id"] = "99999"
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Current user not found")
    end

    it "returns unauthorized if X-User-Id is not numeric" do
      request.headers["X-User-Id"] = "abc"
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Current user not found")
    end
  end
end
