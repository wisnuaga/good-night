require "rails_helper"

RSpec.describe SleepRecordUsecase::List do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }

  context "without followees" do
    let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo) }

    it "lists records for only the user" do
      expect(sleep_record_repo).to receive(:list_by_user_ids).with([1]).and_return([:record])
      result = usecase.call
      expect(result.success?).to be true
      expect(result.data[:data]).to eq([:record])
    end
  end

  context "with followees" do
    let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo, include_followees: true) }

    it "lists records for user and followees" do
      allow(follow_repo).to receive(:list_followee_ids).with(follower_id: user.id).and_return([2, 3])
      expect(sleep_record_repo).to receive(:list_by_user_ids).with([2, 3, 1]).and_return([:record])
      result = usecase.call
      expect(result.success?).to be true
      expect(result.data[:data]).to eq([:record])
    end
  end
end
