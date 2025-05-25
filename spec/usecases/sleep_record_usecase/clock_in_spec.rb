require "rails_helper"

RSpec.describe SleepRecordUsecase::ClockIn do
  let(:user) { instance_double("User", id: 1) }
  let(:sleep_record_repo) { instance_double(SleepRecordRepository) }
  let(:follow_repo) { instance_double(FollowRepository) }
  let(:usecase) { described_class.new(user, sleep_record_repository: sleep_record_repo, follow_repository: follow_repo, clock_in: Time.current) }

  context "when user has no active session" do
    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user_id: user.id).and_return(nil)
      allow(sleep_record_repo).to receive(:create).and_return(double(persisted?: true))
    end

    it "returns success" do
      result = usecase.call
      expect(result.success?).to be true
    end
  end

  context "when user has an active session" do
    before do
      allow(sleep_record_repo).to receive(:find_active_by_user).with(user_id: user.id).and_return(double(persisted?: true))
    end

    it "returns failure" do
      result = usecase.call
      expect(result.success?).to be false
      expect(result.error).to eq("You already have an active sleep session")
    end
  end
end
