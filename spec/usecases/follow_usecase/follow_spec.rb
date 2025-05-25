require "rails_helper"

RSpec.describe FollowUsecase::Follow do
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
    context "when both users exist and not already following" do
      it "returns success" do
        allow(user_repository).to receive(:find_by_id).with(id: followee.id).and_return(followee)
        allow(follow_repository).to receive(:exists?).with(follower: follower, followee: followee).and_return(false)
        follow = double(:follow, persisted?: true)
        allow(follow_repository).to receive(:create).with(follower: follower, followee: followee).and_return(follow)

        result = subject.call
        expect(result.success?).to be true
        expect(result.data[:message]).to eq("Followed user successfully")
      end
    end

    context "when already following" do
      it "returns failure" do
        allow(user_repository).to receive(:find_by_id).with(id: followee.id).and_return(followee)
        allow(follow_repository).to receive(:exists?).with(follower: follower, followee: followee).and_return(true)

        result = subject.call
        expect(result.success?).to be false
        expect(result.error).to eq("Already following this user")
      end
    end

    context "when followee not found" do
      it "returns failure" do
        allow(user_repository).to receive(:find_by_id).with(id: followee.id).and_return(nil)

        result = subject.call
        expect(result.success?).to be false
        expect(result.error).to eq("Followed user not found")
      end
    end
  end
end
