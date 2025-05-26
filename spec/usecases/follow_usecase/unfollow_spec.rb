require "rails_helper"

RSpec.describe FollowUsecase::Unfollow do
  let(:follower) { create(:user) }
  let(:followee) { create(:user) }
  let(:follow_repository) { instance_double(FollowRepository) }
  let(:user_repository) { instance_double(UserRepository) }

  subject do
    described_class.new(
      follower,
      followee.id,
      follow_repository: follow_repository,
      user_repository: user_repository
    )
  end

  describe "#call" do
    context "when following and both users exist" do
      it "returns success" do
        follow = double(:follow)
        allow(user_repository).to receive(:find_by_id).with(followee.id).and_return(followee)
        allow(follow_repository).to receive(:find_by_follower_and_followee).with(follower: follower, followee: followee).and_return(follow)
        allow(follow).to receive(:destroy!).and_return(true)

        result = subject.call
        expect(result.success?).to be true
        expect(result.data[:message]).to eq("Unfollowed user successfully")
      end
    end

    context "when not following" do
      it "returns failure" do
        allow(user_repository).to receive(:find_by_id).with(followee.id).and_return(followee)
        allow(follow_repository).to receive(:find_by_follower_and_followee).with(follower: follower, followee: followee).and_return(nil)

        result = subject.call
        expect(result.success?).to be false
        expect(result.error).to eq("Not following this user")
      end
    end

    context "when followee not found" do
      it "returns failure" do
        allow(user_repository).to receive(:find_by_id).with(followee.id).and_return(nil)

        result = subject.call
        expect(result.success?).to be false
        expect(result.error).to eq("Followed user not found")
      end
    end
  end
end
