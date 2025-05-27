require "rails_helper"

RSpec.describe SleepRecordUsecase::ClockIn do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }
  let(:clock_in_time) { Time.current }
  let(:usecase) do
    described_class.new(
      user,
      sleep_record_repository: sleep_record_repo,
      follow_repository: follow_repo,
      clock_in: clock_in_time
    )
  end
  let(:persisted_record) { instance_double("SleepRecord", id: 123, persisted?: true, user_id: user.id, clock_in: clock_in_time) }

  before do
    allow(sleep_record_repo).to receive(:find_active_by_user).with(user.id).and_return(nil)
    allow(sleep_record_repo).to receive(:create).and_return(persisted_record)
  end

  context "when user has no active session" do
    it "returns success" do
      result = usecase.call
      expect(result.success?).to be true
    end
  end

  context "when user has an active session" do
    let(:follower_ids) { [1, 2, 3] }

    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user.id).and_return(instance_double("SleepRecord", persisted?: true))
    end

    it "returns failure with appropriate message" do
      result = usecase.call
      expect(result.success?).to be false
      expect(result.error).to eq("You already have an active sleep session")
    end
  end
end
