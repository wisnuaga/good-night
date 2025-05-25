require "rails_helper"

RSpec.describe SleepRecordUsecase::List do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }

  context "without followees" do
    let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo) }

    it "falls back to list_by_user_ids when fanout is empty" do
      expect(sleep_record_repo).to receive(:list_fanout).with(user_id: user.id).and_return([])
      expect(sleep_record_repo).to receive(:list_by_user_ids).with([1]).and_return([:record])

      result = usecase.call
      expect(result.success?).to be true
      expect(result.data[:data]).to eq([:record])
    end

    it "returns fanout results if present" do
      expect(sleep_record_repo).to receive(:list_fanout).with(user_id: user.id).and_return([:fanout_record])

      result = usecase.call
      expect(result.success?).to be true
      expect(result.data[:data]).to eq([:fanout_record])
    end
  end

  context "with followees" do
    let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo, include_followees: true) }

    it "falls back to list_by_user_ids for user and followees when fanout is empty" do
      expect(sleep_record_repo).to receive(:list_fanout).with(user_id: user.id).and_return([])
      expect(follow_repo).to receive(:list_followee_ids).with(user_id: user.id).and_return([2, 3])
      expect(sleep_record_repo).to receive(:list_by_user_ids).with([2, 3, 1]).and_return([:record])

      result = usecase.call
      expect(result.success?).to be true
      expect(result.data[:data]).to eq([:record])
    end

    it "returns fanout results if present, without calling list_by_user_ids" do
      expect(sleep_record_repo).to receive(:list_fanout).with(user_id: user.id).and_return([:fanout_record])
      expect(follow_repo).not_to receive(:list_followee_ids)
      expect(sleep_record_repo).not_to receive(:list_by_user_ids)

      result = usecase.call
      expect(result.success?).to be true
      expect(result.data[:data]).to eq([:fanout_record])
    end
  end
end
