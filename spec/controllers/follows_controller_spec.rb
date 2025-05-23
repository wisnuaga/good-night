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

    it "returns error if already following and DB constraint is violated" do
      Follow.create!(follower: alice, followed: bob)
      # Simulate a direct DB constraint violation (e.g., skipping model validation)
      expect {
        Follow.create!(follower_id: alice.id, followed_id: bob.id)
      }.to raise_error(ActiveRecord::RecordInvalid)
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

    it "returns error if trying to unfollow self" do
      put :unfollow, params: { id: alice.id }
      expect(response).to have_http_status(:bad_request).or have_http_status(:not_found)
    end

    it "returns error if unfollow with invalid user id" do
      put :unfollow, params: { id: "invalid" }
      expect(response).to have_http_status(:not_found).or have_http_status(:bad_request)
    end
  end

  describe "authentication" do
    it "returns unauthorized if X-User-Id header is missing" do
      request.headers["X-User-Id"] = nil
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("X-User-Id header missing or invalid")
    end

    it "returns unauthorized if X-User-Id is invalid" do
      request.headers["X-User-Id"] = "99999"
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("X-User-Id header missing or invalid")
    end

    it "returns unauthorized if X-User-Id is blank string" do
      request.headers["X-User-Id"] = ""
      put :follow, params: { id: bob.id }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
